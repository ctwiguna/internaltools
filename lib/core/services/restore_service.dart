import 'package:flutter/foundation.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Service to backup/restore data between local SQLite and Supabase
class BackupRestoreService {
  BackupRestoreService._();

  static final BackupRestoreService _instance = BackupRestoreService._();
  static BackupRestoreService get instance => _instance;

  final SupabaseService _supabase = SupabaseService.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isRestoring = false;
  bool get isRestoring => _isRestoring;

  bool _isBackingUp = false;
  bool get isBackingUp => _isBackingUp;

  /// Backup (upload) all local data to Supabase cloud
  /// This uploads all existing local data that hasn't been synced yet
  /// Supports multi-outlet: each outlet's data is uploaded to its respective cloud outlet
  Future<BackupResult> backupToCloud() async {
    if (_isBackingUp) {
      return BackupResult(
        success: false,
        message: 'Backup sedang berjalan',
      );
    }

    if (!_supabase.isAuthenticated) {
      return BackupResult(
        success: false,
        message: 'Anda harus login dengan akun cloud terlebih dahulu',
      );
    }

    _isBackingUp = true;
    final logBuffer = StringBuffer();

    void log(String message) {
      debugPrint(message);
      logBuffer.writeln(message);
    }

    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) {
        return BackupResult(
          success: false,
          message: 'User tidak ditemukan',
        );
      }

      // Get user's default outlet (for settings and users without outlet_id)
      final profile = await _supabase.client
          .from('profiles')
          .select('outlet_id')
          .eq('id', userId)
          .single();

      final defaultOutletId = profile['outlet_id'] as String?;
      if (defaultOutletId == null) {
        return BackupResult(
          success: false,
          message: 'Outlet tidak ditemukan. Silakan hubungi admin.',
        );
      }

      log('=== BACKUP STARTED ===');
      log('User ID: $userId');
      log('Default outlet: $defaultOutletId');

      final db = await _dbHelper.database;

      // Get all local outlets that need to be synced
      final localOutlets = await db.query('outlets');
      log('Backup: Found ${localOutlets.length} local outlets');

      int customersUploaded = 0;
      int servicesUploaded = 0;
      int ordersUploaded = 0;
      int orderItemsUploaded = 0;
      int paymentsUploaded = 0;
      int outletsUploaded = 0;
      int settingsUploaded = 0;
      int usersUploaded = 0;

      // Build a map of local outlet_id (string) -> remote outlet_id (UUID)
      final Map<String, String> outletIdMap = {};

      // 0. First, sync all local outlets to cloud
      for (final localOutlet in localOutlets) {
        try {
          final localOutletId = localOutlet['id'].toString();
          final outletName = localOutlet['name'] as String;
          log('Backup: Processing outlet "$outletName" (local_id: $localOutletId)');

          // Always check cloud first by name (unique identifier per owner)
          final existingInCloud = await _supabase.client
              .from('outlets')
              .select('id')
              .eq('owner_id', userId)
              .eq('name', outletName)
              .maybeSingle();

          String cloudOutletId;
          if (existingInCloud != null) {
            cloudOutletId = existingInCloud['id'] as String;
            // Update existing outlet in cloud
            await _supabase.client.from('outlets').update({
              'name': localOutlet['name'],
              'address': localOutlet['address'],
              'phone': localOutlet['phone'],
              'invoice_prefix': localOutlet['invoice_prefix'] ?? 'INV',
            }).eq('id', cloudOutletId);
            log('Backup: Outlet "$outletName" updated in cloud');
          } else {
            // Create new outlet in cloud
            final inserted = await _supabase.insert('outlets', {
              'name': localOutlet['name'],
              'address': localOutlet['address'],
              'phone': localOutlet['phone'],
              'invoice_prefix': localOutlet['invoice_prefix'] ?? 'INV',
              'owner_id': userId,
            });
            cloudOutletId = inserted['id'] as String;
            log('Backup: Outlet "$outletName" inserted to cloud with id: $cloudOutletId');
          }

          // Update local outlet with remote_id
          await db.update(
            'outlets',
            {'remote_id': cloudOutletId},
            where: 'id = ?',
            whereArgs: [localOutlet['id']],
          );
          outletIdMap[localOutletId] = cloudOutletId;
          outletsUploaded++;
        } catch (e) {
          log('Backup: Outlet upload error: $e');
        }
      }

      // Also map default outlet for data without outlet_id
      outletIdMap[''] = defaultOutletId;
      outletIdMap['null'] = defaultOutletId;

      log('Backup: $outletsUploaded outlets synced, mapping: $outletIdMap');

      // 0.5. Upload app_settings per outlet (from outlets table data)
      try {
        log('Backup: Uploading app_settings per outlet...');

        // For each local outlet, upload its specific settings
        for (final localOutlet in localOutlets) {
          final localOutletId = localOutlet['id'].toString();
          final cloudOutletId = outletIdMap[localOutletId];

          if (cloudOutletId == null || cloudOutletId.isEmpty) {
            log('Backup: Skipping settings for outlet $localOutletId - no cloud mapping');
            continue;
          }

          // Settings from outlet data
          final outletSettings = {
            'laundry_name': localOutlet['name'],
            'laundry_address': localOutlet['address'] ?? '',
            'laundry_phone': localOutlet['phone'] ?? '',
            'invoice_prefix': localOutlet['invoice_prefix'] ?? 'INV',
          };

          // Also get some global settings from app_settings table
          final globalSettings = await db.query('app_settings');
          final globalSettingsMap = <String, String>{};
          for (final s in globalSettings) {
            final key = s['key'] as String;
            // Only include non-outlet-specific settings
            if (!['laundry_name', 'laundry_address', 'laundry_phone', 'invoice_prefix', 'current_outlet_id'].contains(key)) {
              globalSettingsMap[key] = s['value']?.toString() ?? '';
            }
          }

          // Merge outlet-specific and global settings
          final allSettings = {...globalSettingsMap, ...outletSettings};

          for (final entry in allSettings.entries) {
            try {
              await _supabase.client.from('app_settings').upsert({
                'outlet_id': cloudOutletId,
                'key': entry.key,
                'value': entry.value,
              }, onConflict: 'outlet_id,key');
              settingsUploaded++;
              log('Backup: Setting ${entry.key}=${entry.value} uploaded to outlet $cloudOutletId');
            } catch (e) {
              log('Backup: Setting ${entry.key} upload error: $e');
            }
          }
        }
        log('Backup: $settingsUploaded settings uploaded across all outlets');
      } catch (e) {
        log('Backup: Settings upload error: $e');
      }

      // 0.6. Upload local users (kasir only, not owner) - use default outlet
      try {
        final users = await db.query(
          'users',
          where: 'role = ?',
          whereArgs: ['kasir'],
        );

        for (final user in users) {
          try {
            final username = user['username'] as String;

            // Check if already exists
            final existing = await _supabase.client
                .from('local_users')
                .select('id')
                .eq('outlet_id', defaultOutletId)
                .eq('username', username)
                .maybeSingle();

            if (existing != null) {
              // Update existing
              await _supabase.client.from('local_users').update({
                'password_hash': user['password_hash'],
                'name': user['name'],
                'is_active': user['is_active'] == 1,
              }).eq('id', existing['id']);
            } else {
              // Insert new
              await _supabase.insert('local_users', {
                'outlet_id': defaultOutletId,
                'username': user['username'],
                'password_hash': user['password_hash'],
                'name': user['name'],
                'role': user['role'],
                'is_active': user['is_active'] == 1,
              });
            }
            usersUploaded++;
          } catch (e) {
            log('Backup: User upload error: $e');
          }
        }
        log('Backup: $usersUploaded kasir users uploaded');
      } catch (e) {
        log('Backup: Users upload error: $e');
      }

      // Helper function to get cloud outlet_id from local outlet_id
      String getCloudOutletId(dynamic localOutletId) {
        log('Backup: getCloudOutletId called with: "$localOutletId" (type: ${localOutletId.runtimeType})');
        if (localOutletId == null) {
          log('Backup: localOutletId is null, using default: $defaultOutletId');
          return defaultOutletId;
        }
        final key = localOutletId.toString().trim();
        log('Backup: Looking up key="$key" in outletIdMap');
        final mapped = outletIdMap[key];
        if (mapped == null) {
          log('Backup: No mapping for localOutletId="$key", available keys: ${outletIdMap.keys.toList()}, using default: $defaultOutletId');
          return defaultOutletId;
        }
        log('Backup: Found mapping: "$key" -> "$mapped"');
        return mapped;
      }

      log('Backup: Outlet ID mapping: $outletIdMap');

      // 1. Upload customers (both new and updated) - per outlet
      final customers = await db.query('customers');
      log('Backup: Found ${customers.length} customers to upload');
      for (final customer in customers) {
        try {
          final cloudOutletId = getCloudOutletId(customer['outlet_id']);
          final phone = customer['phone'] as String?;
          final customerName = customer['name'] as String;
          log('Backup: Processing customer "$customerName" (local_id: ${customer['id']}, outlet: $cloudOutletId, phone: $phone)');

          // Always check cloud first by phone (unique identifier per outlet)
          Map<String, dynamic>? existingInCloud;
          if (phone != null && phone.isNotEmpty) {
            existingInCloud = await _supabase.client
                .from('customers')
                .select('id')
                .eq('outlet_id', cloudOutletId)
                .eq('phone', phone)
                .maybeSingle();
          }

          String remoteCustomerId;
          if (existingInCloud != null) {
            remoteCustomerId = existingInCloud['id'] as String;
            // Update existing in cloud
            await _supabase.client.from('customers').update({
              'name': customer['name'],
              'address': customer['address'],
              'notes': customer['notes'],
              'total_orders': customer['total_orders'],
              'total_spent': customer['total_spent'],
            }).eq('id', remoteCustomerId);
            log('Backup: Customer "$customerName" updated in cloud');
          } else {
            // Insert new customer
            final inserted = await _supabase.insert('customers', {
              'outlet_id': cloudOutletId,
              'name': customer['name'],
              'phone': customer['phone'],
              'address': customer['address'],
              'notes': customer['notes'],
            });
            remoteCustomerId = inserted['id'] as String;
            log('Backup: Customer "$customerName" inserted to cloud with id: $remoteCustomerId');
          }

          // Update local with remote_id
          await db.update(
            'customers',
            {'remote_id': remoteCustomerId},
            where: 'id = ?',
            whereArgs: [customer['id']],
          );
          customersUploaded++;
        } catch (e, stack) {
          log('Backup: Customer upload error: $e\n$stack');
        }
      }
      log('Backup: $customersUploaded customers uploaded');

      // 2. Upload services (both new and updated) - per outlet
      final services = await db.query('services');
      log('Backup: Found ${services.length} services to upload');
      log('Backup: OutletIdMap for services: $outletIdMap');
      for (final service in services) {
        try {
          final localOutletId = service['outlet_id'];
          final cloudOutletId = getCloudOutletId(localOutletId);
          final serviceName = service['name'] as String;
          log('Backup: Processing service "$serviceName" (local_id: ${service['id']}, local_outlet_id: "$localOutletId" (type: ${localOutletId.runtimeType}), cloud_outlet_id: $cloudOutletId)');

          // Always check cloud first by name (unique identifier per outlet)
          final existingInCloud = await _supabase.client
              .from('services')
              .select('id')
              .eq('outlet_id', cloudOutletId)
              .eq('name', serviceName)
              .maybeSingle();

          String remoteServiceId;
          if (existingInCloud != null) {
            remoteServiceId = existingInCloud['id'] as String;
            // Update existing in cloud
            await _supabase.client.from('services').update({
              'name': service['name'],
              'unit': service['unit'],
              'price': service['price'],
              'duration_days': service['duration_days'],
              'is_active': service['is_active'] == 1,
            }).eq('id', remoteServiceId);
            log('Backup: Service "$serviceName" updated in cloud');
          } else {
            // Insert new service
            final inserted = await _supabase.insert('services', {
              'outlet_id': cloudOutletId,
              'name': service['name'],
              'unit': service['unit'],
              'price': service['price'],
              'duration_days': service['duration_days'],
              'is_active': service['is_active'] == 1,
            });
            remoteServiceId = inserted['id'] as String;
            log('Backup: Service "$serviceName" inserted to cloud with id: $remoteServiceId');
          }

          // Update local with remote_id
          await db.update(
            'services',
            {'remote_id': remoteServiceId},
            where: 'id = ?',
            whereArgs: [service['id']],
          );
          servicesUploaded++;
        } catch (e, stack) {
          log('Backup: Service upload error: $e\n$stack');
        }
      }
      log('Backup: $servicesUploaded services uploaded');

      // 3. Upload orders with items and payments (both new and updated) - per outlet
      final orders = await db.query('orders', orderBy: 'created_at ASC');
      log('Backup: Found ${orders.length} orders to upload');
      for (final order in orders) {
        try {
          final existingRemoteId = order['remote_id'] as String?;
          log('Backup: Processing order ${order['invoice_no']}, local_id: ${order['id']}, outlet_id: ${order['outlet_id']}, existing remote_id: $existingRemoteId');
          final cloudOutletId = getCloudOutletId(order['outlet_id']);
          log('Backup: Order ${order['invoice_no']} mapped to cloud outlet: $cloudOutletId');

          // Get remote customer_id if exists
          String? remoteCustomerId;
          final localCustomerId = order['customer_id'] as int?;
          if (localCustomerId != null) {
            final customerResult = await db.query(
              'customers',
              columns: ['remote_id'],
              where: 'id = ?',
              whereArgs: [localCustomerId],
            );
            if (customerResult.isNotEmpty) {
              remoteCustomerId = customerResult.first['remote_id'] as String?;
            }
          }

          String remoteOrderId;
          final invoiceNo = order['invoice_no'] as String;

          // Always check if order exists in cloud by invoice_no first
          final existingInCloud = await _supabase.client
              .from('orders')
              .select('id')
              .eq('outlet_id', cloudOutletId)
              .eq('invoice_no', invoiceNo)
              .maybeSingle();

          if (existingInCloud != null) {
            remoteOrderId = existingInCloud['id'] as String;
            // Update existing order in cloud
            await _supabase.client.from('orders').update({
              'customer_id': remoteCustomerId,
              'customer_name': order['customer_name'],
              'customer_phone': order['customer_phone'],
              'status': order['status'],
              'total_items': order['total_items'],
              'total_weight': order['total_weight'],
              'total_price': order['total_price'],
              'paid': order['paid'],
              'notes': order['notes'],
            }).eq('id', remoteOrderId);
            log('Backup: Order ${order['invoice_no']} updated in cloud');
          } else {
            // Insert new order
            final inserted = await _supabase.insert('orders', {
              'outlet_id': cloudOutletId,
              'customer_id': remoteCustomerId,
              'invoice_no': order['invoice_no'],
              'customer_name': order['customer_name'],
              'customer_phone': order['customer_phone'],
              'order_date': order['order_date'],
              'due_date': order['due_date'],
              'status': order['status'],
              'total_items': order['total_items'],
              'total_weight': order['total_weight'],
              'total_price': order['total_price'],
              'paid': order['paid'],
              'notes': order['notes'],
            });
            remoteOrderId = inserted['id'] as String;
            log('Backup: Order ${order['invoice_no']} inserted to cloud with id: $remoteOrderId');
          }

          // Update local order with remote_id
          await db.update(
            'orders',
            {'remote_id': remoteOrderId},
            where: 'id = ?',
            whereArgs: [order['id']],
          );
          ordersUploaded++;

          // Upload order items
          final items = await db.query(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [order['id']],
          );
          for (final item in items) {
            try {
              // Get service_id by looking up the service's remote_id
              String? remoteServiceId;
              final localServiceId = item['service_id'] as int?;
              if (localServiceId != null) {
                final serviceResult = await db.query(
                  'services',
                  columns: ['remote_id'],
                  where: 'id = ?',
                  whereArgs: [localServiceId],
                );
                if (serviceResult.isNotEmpty) {
                  remoteServiceId = serviceResult.first['remote_id'] as String?;
                }
              }

              // If no service_id found by ID, try to find by service_name in the same outlet
              if (remoteServiceId == null) {
                final serviceName = item['service_name'] as String?;
                if (serviceName != null && serviceName.isNotEmpty) {
                  final existingService = await _supabase.client
                      .from('services')
                      .select('id')
                      .eq('outlet_id', cloudOutletId)
                      .eq('name', serviceName)
                      .maybeSingle();
                  if (existingService != null) {
                    remoteServiceId = existingService['id'] as String;
                  }
                }
              }

              // Check if order_item already exists in cloud by order_id + service_name
              final serviceName = item['service_name'] as String;
              final existingItemInCloud = await _supabase.client
                  .from('order_items')
                  .select('id')
                  .eq('order_id', remoteOrderId)
                  .eq('service_name', serviceName)
                  .maybeSingle();

              String remoteItemId;
              if (existingItemInCloud != null) {
                remoteItemId = existingItemInCloud['id'] as String;
                // Update existing
                await _supabase.client.from('order_items').update({
                  'service_id': remoteServiceId,
                  'quantity': item['quantity'],
                  'unit': item['unit'],
                  'price_per_unit': item['price_per_unit'],
                  'subtotal': item['subtotal'],
                }).eq('id', remoteItemId);
                log('Backup: Order item "$serviceName" updated with service_id: $remoteServiceId');
              } else {
                // Insert new
                final insertedItem = await _supabase.insert('order_items', {
                  'order_id': remoteOrderId,
                  'service_id': remoteServiceId,
                  'service_name': item['service_name'],
                  'quantity': item['quantity'],
                  'unit': item['unit'],
                  'price_per_unit': item['price_per_unit'],
                  'subtotal': item['subtotal'],
                });
                remoteItemId = insertedItem['id'] as String;
                log('Backup: Order item "$serviceName" inserted with service_id: $remoteServiceId');
              }

              await db.update(
                'order_items',
                {'remote_id': remoteItemId},
                where: 'id = ?',
                whereArgs: [item['id']],
              );
              orderItemsUploaded++;
            } catch (e) {
              log('Backup: Order item upload error: $e');
            }
          }

          // Upload payments
          final payments = await db.query(
            'payments',
            where: 'order_id = ?',
            whereArgs: [order['id']],
          );
          for (final payment in payments) {
            try {
              final paymentDate = payment['payment_date'] as String?;
              final paymentMethod = payment['payment_method'] as String?;
              final amount = payment['amount'] as num?;

              // Check if payment already exists by order_id + payment_date + amount
              Map<String, dynamic>? existingPaymentInCloud;
              if (paymentDate != null && amount != null) {
                existingPaymentInCloud = await _supabase.client
                    .from('payments')
                    .select('id')
                    .eq('order_id', remoteOrderId)
                    .eq('payment_date', paymentDate)
                    .eq('amount', amount)
                    .maybeSingle();
              }

              String remotePaymentId;
              if (existingPaymentInCloud != null) {
                remotePaymentId = existingPaymentInCloud['id'] as String;
                // Update existing
                await _supabase.client.from('payments').update({
                  'change_amount': payment['change'] ?? 0,
                  'payment_method': paymentMethod,
                  'notes': payment['notes'],
                }).eq('id', remotePaymentId);
                log('Backup: Payment updated');
              } else {
                // Insert new
                final insertedPayment = await _supabase.insert('payments', {
                  'order_id': remoteOrderId,
                  'amount': payment['amount'],
                  'change_amount': payment['change'] ?? 0,
                  'payment_date': payment['payment_date'],
                  'payment_method': payment['payment_method'],
                  'notes': payment['notes'],
                });
                remotePaymentId = insertedPayment['id'] as String;
                log('Backup: Payment inserted');
              }

              await db.update(
                'payments',
                {'remote_id': remotePaymentId},
                where: 'id = ?',
                whereArgs: [payment['id']],
              );
              paymentsUploaded++;
            } catch (e) {
              log('Backup: Payment upload error: $e');
            }
          }
        } catch (e, stack) {
          log('Backup: Order upload error: $e\n$stack');
        }
      }
      log('Backup: $ordersUploaded orders, $orderItemsUploaded items, $paymentsUploaded payments uploaded');
      log('=== BACKUP COMPLETED ===');

      return BackupResult(
        success: true,
        message: 'Data berhasil diupload ke cloud',
        outletsUploaded: outletsUploaded,
        settingsUploaded: settingsUploaded,
        usersUploaded: usersUploaded,
        customersUploaded: customersUploaded,
        servicesUploaded: servicesUploaded,
        ordersUploaded: ordersUploaded,
        orderItemsUploaded: orderItemsUploaded,
        paymentsUploaded: paymentsUploaded,
        logs: logBuffer.toString(),
      );
    } catch (e) {
      log('Backup error: $e');
      log('=== BACKUP FAILED ===');
      return BackupResult(
        success: false,
        message: 'Gagal backup: ${e.toString()}',
        logs: logBuffer.toString(),
      );
    } finally {
      _isBackingUp = false;
    }
  }

  /// Reset all remote_ids in local database
  /// Use this before re-uploading all data to cloud after deleting cloud data
  Future<void> resetAllRemoteIds() async {
    final db = await _dbHelper.database;

    debugPrint('Reset: Clearing all remote_ids...');

    // Reset outlets (keep them, just remove remote_id)
    await db.rawUpdate('UPDATE outlets SET remote_id = NULL');
    debugPrint('Reset: Outlets remote_id cleared');

    // Reset customers
    await db.rawUpdate('UPDATE customers SET remote_id = NULL');
    debugPrint('Reset: Customers remote_id cleared');

    // Reset services
    await db.rawUpdate('UPDATE services SET remote_id = NULL');
    debugPrint('Reset: Services remote_id cleared');

    // Reset orders
    await db.rawUpdate('UPDATE orders SET remote_id = NULL');
    debugPrint('Reset: Orders remote_id cleared');

    // Reset order_items
    await db.rawUpdate('UPDATE order_items SET remote_id = NULL');
    debugPrint('Reset: Order items remote_id cleared');

    // Reset payments
    await db.rawUpdate('UPDATE payments SET remote_id = NULL');
    debugPrint('Reset: Payments remote_id cleared');

    debugPrint('Reset: All remote_ids cleared successfully');
  }

  /// Fix inconsistent outlet_id in local database
  /// Some old data has UUID (remote_id) as outlet_id instead of local integer id
  Future<String> fixLocalOutletIds() async {
    final db = await _dbHelper.database;
    final buffer = StringBuffer();

    buffer.writeln('=== FIXING LOCAL OUTLET IDs ===\n');

    // Get all outlets with their remote_id
    final outlets = await db.query('outlets');
    final Map<String, int> remoteToLocalMap = {};

    for (final outlet in outlets) {
      final localId = outlet['id'] as int;
      final remoteId = outlet['remote_id'] as String?;
      if (remoteId != null) {
        remoteToLocalMap[remoteId] = localId;
      }
    }

    buffer.writeln('Outlet mapping (remote -> local): $remoteToLocalMap\n');

    // Fix customers
    int customersFixed = 0;
    final customers = await db.query('customers');
    for (final c in customers) {
      final outletId = c['outlet_id']?.toString();
      if (outletId != null && outletId.contains('-')) {
        // This is a UUID, need to convert to local id
        final localOutletId = remoteToLocalMap[outletId];
        if (localOutletId != null) {
          await db.update(
            'customers',
            {'outlet_id': localOutletId.toString()},
            where: 'id = ?',
            whereArgs: [c['id']],
          );
          customersFixed++;
          buffer.writeln('Fixed customer ${c['id']} "${c['name']}": $outletId -> $localOutletId');
        }
      }
    }
    buffer.writeln('Customers fixed: $customersFixed\n');

    // Fix services
    int servicesFixed = 0;
    final services = await db.query('services');
    for (final s in services) {
      final outletId = s['outlet_id']?.toString();
      if (outletId != null && outletId.contains('-')) {
        final localOutletId = remoteToLocalMap[outletId];
        if (localOutletId != null) {
          await db.update(
            'services',
            {'outlet_id': localOutletId.toString()},
            where: 'id = ?',
            whereArgs: [s['id']],
          );
          servicesFixed++;
          buffer.writeln('Fixed service ${s['id']} "${s['name']}": $outletId -> $localOutletId');
        }
      }
    }
    buffer.writeln('Services fixed: $servicesFixed\n');

    // Fix orders
    int ordersFixed = 0;
    final orders = await db.query('orders');
    for (final o in orders) {
      final outletId = o['outlet_id']?.toString();
      if (outletId != null && outletId.contains('-')) {
        final localOutletId = remoteToLocalMap[outletId];
        if (localOutletId != null) {
          await db.update(
            'orders',
            {'outlet_id': localOutletId.toString()},
            where: 'id = ?',
            whereArgs: [o['id']],
          );
          ordersFixed++;
          buffer.writeln('Fixed order ${o['id']} "${o['invoice_no']}": $outletId -> $localOutletId');
        }
      }
    }
    buffer.writeln('Orders fixed: $ordersFixed\n');

    buffer.writeln('=== DONE ===');
    buffer.writeln('Total fixed: ${customersFixed + servicesFixed + ordersFixed}');

    return buffer.toString();
  }

  /// Get debug info about all local data
  Future<String> getDebugLocalData() async {
    final db = await _dbHelper.database;
    final buffer = StringBuffer();

    // 1. Outlets
    buffer.writeln('=== OUTLETS ===');
    final outlets = await db.query('outlets');
    buffer.writeln('Total: ${outlets.length}');
    for (final o in outlets) {
      buffer.writeln('  id: ${o['id']}, name: ${o['name']}, outlet_id: ${o['outlet_id'] ?? 'NULL'}, remote_id: ${o['remote_id'] ?? 'NULL'}');
    }
    buffer.writeln();

    // 2. Customers
    buffer.writeln('=== CUSTOMERS ===');
    final customers = await db.query('customers');
    buffer.writeln('Total: ${customers.length}');
    for (final c in customers) {
      buffer.writeln('  id: ${c['id']}, name: ${c['name']}, phone: ${c['phone']}, outlet_id: ${c['outlet_id'] ?? 'NULL'}, remote_id: ${c['remote_id'] ?? 'NULL'}');
    }
    buffer.writeln();

    // 3. Services
    buffer.writeln('=== SERVICES ===');
    final services = await db.query('services');
    buffer.writeln('Total: ${services.length}');
    for (final s in services) {
      buffer.writeln('  id: ${s['id']}, name: ${s['name']}, outlet_id: ${s['outlet_id'] ?? 'NULL'}, remote_id: ${s['remote_id'] ?? 'NULL'}');
    }
    buffer.writeln();

    // 4. Orders (last 10)
    buffer.writeln('=== ORDERS (last 10) ===');
    final orders = await db.query('orders', orderBy: 'created_at DESC', limit: 10);
    buffer.writeln('Total (showing last 10): ${orders.length}');
    for (final o in orders) {
      buffer.writeln('  id: ${o['id']}, invoice: ${o['invoice_no']}, outlet_id: ${o['outlet_id'] ?? 'NULL'}, customer_id: ${o['customer_id'] ?? 'NULL'}, remote_id: ${o['remote_id'] ?? 'NULL'}');
    }
    buffer.writeln();

    // 5. Order Items (last 10)
    buffer.writeln('=== ORDER_ITEMS (last 10) ===');
    final orderItems = await db.query('order_items', orderBy: 'id DESC', limit: 10);
    buffer.writeln('Total (showing last 10): ${orderItems.length}');
    for (final i in orderItems) {
      buffer.writeln('  id: ${i['id']}, order_id: ${i['order_id']}, service_id: ${i['service_id'] ?? 'NULL'}, service_name: ${i['service_name']}, remote_id: ${i['remote_id'] ?? 'NULL'}');
    }
    buffer.writeln();

    // 6. Payments (last 10)
    buffer.writeln('=== PAYMENTS (last 10) ===');
    final payments = await db.query('payments', orderBy: 'id DESC', limit: 10);
    buffer.writeln('Total (showing last 10): ${payments.length}');
    for (final p in payments) {
      buffer.writeln('  id: ${p['id']}, order_id: ${p['order_id']}, amount: ${p['amount']}, remote_id: ${p['remote_id'] ?? 'NULL'}');
    }
    buffer.writeln();

    // 7. App Settings
    buffer.writeln('=== APP_SETTINGS ===');
    final settings = await db.query('app_settings');
    buffer.writeln('Total: ${settings.length}');
    for (final s in settings) {
      buffer.writeln('  key: ${s['key']}, value: ${s['value']}');
    }
    buffer.writeln();

    // 8. Sync Queue
    buffer.writeln('=== SYNC_QUEUE ===');
    try {
      final syncQueue = await db.query('sync_queue', limit: 10);
      buffer.writeln('Total (showing last 10): ${syncQueue.length}');
      for (final sq in syncQueue) {
        buffer.writeln('  id: ${sq['id']}, table: ${sq['table_name']}, operation: ${sq['operation']}, synced: ${sq['synced']}');
      }
    } catch (e) {
      buffer.writeln('  (no sync_queue table)');
    }

    return buffer.toString();
  }

  /// Get count of local data (all data will be synced - both new and updated)
  Future<LocalDataSummary> getLocalDataCount() async {
    final db = await _dbHelper.database;

    final outletsCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM outlets',
    );
    final customersCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customers',
    );
    final servicesCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM services',
    );
    final ordersCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM orders',
    );
    final usersCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM users WHERE role = 'kasir'",
    );

    return LocalDataSummary(
      outletsCount: (outletsCount.first['count'] as int?) ?? 0,
      customersCount: (customersCount.first['count'] as int?) ?? 0,
      servicesCount: (servicesCount.first['count'] as int?) ?? 0,
      ordersCount: (ordersCount.first['count'] as int?) ?? 0,
      usersCount: (usersCount.first['count'] as int?) ?? 0,
    );
  }

  /// Restore all data from Supabase for all user's outlets
  /// Returns a summary of restored data
  Future<RestoreResult> restoreFromCloud() async {
    if (_isRestoring) {
      return RestoreResult(
        success: false,
        message: 'Restore sedang berjalan',
      );
    }

    if (!_supabase.isAuthenticated) {
      return RestoreResult(
        success: false,
        message: 'Anda harus login dengan akun cloud terlebih dahulu',
      );
    }

    _isRestoring = true;

    try {
      // Get user's outlet_id
      final userId = _supabase.currentUser?.id;
      if (userId == null) {
        return RestoreResult(
          success: false,
          message: 'User tidak ditemukan',
        );
      }

      final profile = await _supabase.client
          .from('profiles')
          .select('outlet_id')
          .eq('id', userId)
          .single();

      final defaultOutletId = profile['outlet_id'] as String?;
      if (defaultOutletId == null) {
        return RestoreResult(
          success: false,
          message: 'Outlet tidak ditemukan. Silakan hubungi admin.',
        );
      }

      debugPrint('Restore: Starting multi-outlet restore, default outlet: $defaultOutletId');

      final db = await _dbHelper.database;

      int outletsRestored = 0;
      int settingsRestored = 0;
      int customersRestored = 0;
      int servicesRestored = 0;
      int ordersRestored = 0;
      int orderItemsRestored = 0;
      int paymentsRestored = 0;

      // Map of cloud outlet_id (UUID) -> local outlet_id (int)
      final Map<String, int> outletIdMap = {};

      // 0. First, restore all outlets owned by this user
      try {
        final cloudOutlets = await _supabase.client
            .from('outlets')
            .select()
            .eq('owner_id', userId);

        for (final cloudOutlet in cloudOutlets) {
          final remoteId = cloudOutlet['id'] as String;
          final outletName = cloudOutlet['name'] as String;

          // Check if outlet exists locally by remote_id
          final existingByRemote = await db.query(
            'outlets',
            where: 'remote_id = ?',
            whereArgs: [remoteId],
          );

          int localOutletId;
          if (existingByRemote.isNotEmpty) {
            localOutletId = existingByRemote.first['id'] as int;
            // Update existing outlet
            await db.update(
              'outlets',
              {
                'name': cloudOutlet['name'],
                'address': cloudOutlet['address'],
                'phone': cloudOutlet['phone'],
                'invoice_prefix': cloudOutlet['invoice_prefix'] ?? 'INV',
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [localOutletId],
            );
          } else {
            // Check by name
            final existingByName = await db.query(
              'outlets',
              where: 'name = ?',
              whereArgs: [outletName],
            );

            if (existingByName.isNotEmpty) {
              localOutletId = existingByName.first['id'] as int;
              // Update existing with remote_id
              await db.update(
                'outlets',
                {
                  'remote_id': remoteId,
                  'address': cloudOutlet['address'],
                  'phone': cloudOutlet['phone'],
                  'invoice_prefix': cloudOutlet['invoice_prefix'] ?? 'INV',
                  'updated_at': DateTime.now().toIso8601String(),
                },
                where: 'id = ?',
                whereArgs: [localOutletId],
              );
            } else {
              // Insert new outlet
              localOutletId = await db.insert('outlets', {
                'remote_id': remoteId,
                'name': cloudOutlet['name'],
                'address': cloudOutlet['address'],
                'phone': cloudOutlet['phone'],
                'invoice_prefix': cloudOutlet['invoice_prefix'] ?? 'INV',
                'created_at': cloudOutlet['created_at'],
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          }

          outletIdMap[remoteId] = localOutletId;
          outletsRestored++;
          debugPrint('Restore: Outlet "$outletName" restored (local id: $localOutletId)');
        }
        debugPrint('Restore: $outletsRestored outlets restored');
      } catch (e) {
        debugPrint('Restore: Outlets restore error: $e');
      }

      // 0.5. Restore app_settings (from default outlet)
      try {
        final outlet = await _supabase.client
            .from('outlets')
            .select()
            .eq('id', defaultOutletId)
            .single();

        // Update local app_settings with outlet info
        final settingsToRestore = {
          'laundry_name': outlet['name'],
          'laundry_address': outlet['address'],
          'laundry_phone': outlet['phone'],
          'invoice_prefix': outlet['invoice_prefix'],
        };

        for (final entry in settingsToRestore.entries) {
          if (entry.value != null) {
            await db.rawInsert('''
              INSERT OR REPLACE INTO app_settings (key, value)
              VALUES (?, ?)
            ''', [entry.key, entry.value]);
          }
        }
        debugPrint('Restore: Outlet info restored to app_settings');

        // Restore app_settings from cloud
        final cloudSettings = await _supabase.client
            .from('app_settings')
            .select()
            .eq('outlet_id', defaultOutletId);

        for (final setting in cloudSettings) {
          await db.rawInsert('''
            INSERT OR REPLACE INTO app_settings (key, value)
            VALUES (?, ?)
          ''', [setting['key'], setting['value']]);
          settingsRestored++;
        }
        debugPrint('Restore: $settingsRestored settings restored');
      } catch (e) {
        debugPrint('Restore: Outlet/settings restore error: $e');
      }

      // 0.6. Restore local users (kasir) from cloud
      int usersRestored = 0;
      try {
        final cloudUsers = await _supabase.client
            .from('local_users')
            .select()
            .eq('outlet_id', defaultOutletId);

        for (final cloudUser in cloudUsers) {
          final username = cloudUser['username'] as String;

          // Check if user exists locally
          final existing = await db.query(
            'users',
            where: 'username = ?',
            whereArgs: [username],
          );

          if (existing.isEmpty) {
            // Insert new kasir user
            await db.insert('users', {
              'username': cloudUser['username'],
              'password_hash': cloudUser['password_hash'],
              'name': cloudUser['name'],
              'role': cloudUser['role'],
              'is_active': cloudUser['is_active'] == true ? 1 : 0,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            usersRestored++;
          } else {
            // Update existing user (sync password changes, etc)
            await db.update(
              'users',
              {
                'password_hash': cloudUser['password_hash'],
                'name': cloudUser['name'],
                'is_active': cloudUser['is_active'] == true ? 1 : 0,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'username = ?',
              whereArgs: [username],
            );
            usersRestored++;
          }
        }
        debugPrint('Restore: $usersRestored kasir users restored');
      } catch (e) {
        debugPrint('Restore: Users restore error: $e');
      }

      // Use transaction for atomicity - restore from ALL outlets
      await db.transaction((txn) async {
        // Restore data from each cloud outlet
        for (final entry in outletIdMap.entries) {
          final cloudOutletId = entry.key;
          final localOutletId = entry.value;

          // 1. Restore customers for this outlet
          final customerCount = await _restoreCustomers(txn, cloudOutletId, localOutletId);
          customersRestored += customerCount;

          // 2. Restore services for this outlet
          final serviceCount = await _restoreServices(txn, cloudOutletId, localOutletId);
          servicesRestored += serviceCount;

          // 3. Restore orders (with order_items and payments) for this outlet
          final orderResult = await _restoreOrders(txn, cloudOutletId, localOutletId);
          ordersRestored += orderResult['orders'] ?? 0;
          orderItemsRestored += orderResult['items'] ?? 0;
          paymentsRestored += orderResult['payments'] ?? 0;
        }

        debugPrint('Restore: $customersRestored customers restored');
        debugPrint('Restore: $servicesRestored services restored');
        debugPrint('Restore: $ordersRestored orders, $orderItemsRestored items, $paymentsRestored payments restored');
      });

      return RestoreResult(
        success: true,
        message: 'Data berhasil direstore dari cloud',
        outletsRestored: outletsRestored,
        settingsRestored: settingsRestored,
        usersRestored: usersRestored,
        customersRestored: customersRestored,
        servicesRestored: servicesRestored,
        ordersRestored: ordersRestored,
        orderItemsRestored: orderItemsRestored,
        paymentsRestored: paymentsRestored,
      );
    } catch (e) {
      debugPrint('Restore error: $e');
      return RestoreResult(
        success: false,
        message: 'Gagal restore: ${e.toString()}',
      );
    } finally {
      _isRestoring = false;
    }
  }

  /// Restore customers from Supabase for a specific outlet
  Future<int> _restoreCustomers(Transaction txn, String cloudOutletId, int localOutletId) async {
    final customers = await _supabase.client
        .from('customers')
        .select()
        .eq('outlet_id', cloudOutletId);

    int count = 0;
    for (final customer in customers) {
      final remoteId = customer['id'] as String;

      // Check if already exists by remote_id
      final existing = await txn.query(
        'customers',
        where: 'remote_id = ?',
        whereArgs: [remoteId],
      );

      if (existing.isEmpty) {
        // Check by phone (might exist locally without remote_id)
        final phone = customer['phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          final existingByPhone = await txn.query(
            'customers',
            where: 'phone = ?',
            whereArgs: [phone],
          );

          if (existingByPhone.isNotEmpty) {
            // Update existing with remote_id
            await txn.update(
              'customers',
              {
                'remote_id': remoteId,
                'outlet_id': localOutletId.toString(),
                'name': customer['name'],
                'address': customer['address'],
                'notes': customer['notes'],
              },
              where: 'id = ?',
              whereArgs: [existingByPhone.first['id']],
            );
            count++;
            continue;
          }
        }

        // Insert new customer
        await txn.insert('customers', {
          'remote_id': remoteId,
          'outlet_id': localOutletId.toString(),
          'name': customer['name'],
          'phone': customer['phone'],
          'address': customer['address'],
          'notes': customer['notes'],
          'total_orders': customer['total_orders'] ?? 0,
          'total_spent': customer['total_spent'] ?? 0,
          'created_at': customer['created_at'],
        });
        count++;
      }
    }
    return count;
  }

  /// Restore services from Supabase for a specific outlet
  Future<int> _restoreServices(Transaction txn, String cloudOutletId, int localOutletId) async {
    final services = await _supabase.client
        .from('services')
        .select()
        .eq('outlet_id', cloudOutletId);

    int count = 0;
    for (final service in services) {
      final remoteId = service['id'] as String;

      // Check if already exists
      final existing = await txn.query(
        'services',
        where: 'remote_id = ?',
        whereArgs: [remoteId],
      );

      if (existing.isEmpty) {
        // Check by name (might exist locally)
        final name = service['name'] as String;
        final existingByName = await txn.query(
          'services',
          where: 'name = ?',
          whereArgs: [name],
        );

        if (existingByName.isNotEmpty) {
          // Update existing with remote_id
          await txn.update(
            'services',
            {
              'remote_id': remoteId,
              'outlet_id': localOutletId.toString(),
              'unit': service['unit'],
              'price': service['price'],
              'duration_days': service['duration_days'] ?? 3,
              'is_active': service['is_active'] == true ? 1 : 0,
            },
            where: 'id = ?',
            whereArgs: [existingByName.first['id']],
          );
          count++;
          continue;
        }

        // Insert new service
        await txn.insert('services', {
          'remote_id': remoteId,
          'outlet_id': localOutletId.toString(),
          'name': service['name'],
          'unit': service['unit'],
          'price': service['price'],
          'duration_days': service['duration_days'] ?? 3,
          'is_active': service['is_active'] == true ? 1 : 0,
          'created_at': service['created_at'],
        });
        count++;
      }
    }
    return count;
  }

  /// Restore orders with items and payments from Supabase for a specific outlet
  Future<Map<String, int>> _restoreOrders(Transaction txn, String cloudOutletId, int localOutletId) async {
    int ordersCount = 0;
    int itemsCount = 0;
    int paymentsCount = 0;

    // Get orders with items and payments
    final orders = await _supabase.client
        .from('orders')
        .select('''
          *,
          order_items (*),
          payments (*)
        ''')
        .eq('outlet_id', cloudOutletId)
        .order('created_at', ascending: false);

    for (final order in orders) {
      final remoteId = order['id'] as String;

      // Check if already exists
      final existing = await txn.query(
        'orders',
        where: 'remote_id = ?',
        whereArgs: [remoteId],
      );

      if (existing.isEmpty) {
        // Check by invoice_no (might exist locally)
        final invoiceNo = order['invoice_no'] as String;
        final existingByInvoice = await txn.query(
          'orders',
          where: 'invoice_no = ?',
          whereArgs: [invoiceNo],
        );

        int localOrderId;

        if (existingByInvoice.isNotEmpty) {
          // Update existing with remote_id
          localOrderId = existingByInvoice.first['id'] as int;
          await txn.update(
            'orders',
            {
              'remote_id': remoteId,
              'outlet_id': localOutletId.toString(),
              'status': order['status'],
              'paid': order['paid'],
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [localOrderId],
          );
        } else {
          // Find local customer_id by remote customer_id
          int? localCustomerId;
          final remoteCustomerId = order['customer_id'] as String?;
          if (remoteCustomerId != null) {
            final customerResult = await txn.query(
              'customers',
              columns: ['id'],
              where: 'remote_id = ?',
              whereArgs: [remoteCustomerId],
            );
            if (customerResult.isNotEmpty) {
              localCustomerId = customerResult.first['id'] as int;
            }
          }

          // Insert new order
          localOrderId = await txn.insert('orders', {
            'remote_id': remoteId,
            'outlet_id': localOutletId.toString(),
            'invoice_no': order['invoice_no'],
            'customer_id': localCustomerId,
            'customer_name': order['customer_name'],
            'customer_phone': order['customer_phone'],
            'order_date': order['order_date'],
            'due_date': order['due_date'],
            'status': order['status'],
            'total_items': order['total_items'],
            'total_weight': order['total_weight'],
            'total_price': order['total_price'],
            'paid': order['paid'],
            'notes': order['notes'],
            'created_at': order['created_at'],
            'updated_at': order['updated_at'],
          });
        }
        ordersCount++;

        // Restore order items
        final items = order['order_items'] as List? ?? [];
        for (final item in items) {
          final itemRemoteId = item['id'] as String;

          final existingItem = await txn.query(
            'order_items',
            where: 'remote_id = ?',
            whereArgs: [itemRemoteId],
          );

          if (existingItem.isEmpty) {
            await txn.insert('order_items', {
              'remote_id': itemRemoteId,
              'order_id': localOrderId,
              'service_name': item['service_name'],
              'quantity': item['quantity'],
              'unit': item['unit'],
              'price_per_unit': item['price_per_unit'],
              'subtotal': item['subtotal'],
            });
            itemsCount++;
          }
        }

        // Restore payments
        final payments = order['payments'] as List? ?? [];
        for (final payment in payments) {
          final paymentRemoteId = payment['id'] as String;

          final existingPayment = await txn.query(
            'payments',
            where: 'remote_id = ?',
            whereArgs: [paymentRemoteId],
          );

          if (existingPayment.isEmpty) {
            await txn.insert('payments', {
              'remote_id': paymentRemoteId,
              'order_id': localOrderId,
              'amount': payment['amount'],
              'change': payment['change'] ?? 0,
              'payment_date': payment['payment_date'],
              'payment_method': payment['payment_method'],
              'notes': payment['notes'],
              'created_at': payment['created_at'],
            });
            paymentsCount++;
          }
        }
      }
    }

    return {
      'orders': ordersCount,
      'items': itemsCount,
      'payments': paymentsCount,
    };
  }

  /// Check if there's data available to restore
  Future<CloudDataSummary> checkCloudData() async {
    if (!_supabase.isAuthenticated) {
      return CloudDataSummary(available: false);
    }

    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) {
        return CloudDataSummary(available: false);
      }

      final profile = await _supabase.client
          .from('profiles')
          .select('outlet_id')
          .eq('id', userId)
          .maybeSingle();

      final outletId = profile?['outlet_id'] as String?;
      if (outletId == null) {
        return CloudDataSummary(available: false);
      }

      // Count data in cloud
      final customersCount = await _supabase.client
          .from('customers')
          .select('id')
          .eq('outlet_id', outletId)
          .count();

      final ordersCount = await _supabase.client
          .from('orders')
          .select('id')
          .eq('outlet_id', outletId)
          .count();

      final servicesCount = await _supabase.client
          .from('services')
          .select('id')
          .eq('outlet_id', outletId)
          .count();

      return CloudDataSummary(
        available: true,
        customersCount: customersCount.count,
        ordersCount: ordersCount.count,
        servicesCount: servicesCount.count,
      );
    } catch (e) {
      debugPrint('Check cloud data error: $e');
      return CloudDataSummary(available: false);
    }
  }
}

/// Result of restore operation
class RestoreResult {
  final bool success;
  final String message;
  final int outletsRestored;
  final int settingsRestored;
  final int usersRestored;
  final int customersRestored;
  final int servicesRestored;
  final int ordersRestored;
  final int orderItemsRestored;
  final int paymentsRestored;

  RestoreResult({
    required this.success,
    required this.message,
    this.outletsRestored = 0,
    this.settingsRestored = 0,
    this.usersRestored = 0,
    this.customersRestored = 0,
    this.servicesRestored = 0,
    this.ordersRestored = 0,
    this.orderItemsRestored = 0,
    this.paymentsRestored = 0,
  });

  int get totalRestored =>
      outletsRestored +
      settingsRestored +
      usersRestored +
      customersRestored +
      servicesRestored +
      ordersRestored +
      orderItemsRestored +
      paymentsRestored;

  String get summary => '''
Outlets: $outletsRestored
Settings: $settingsRestored
Users (Kasir): $usersRestored
Customers: $customersRestored
Services: $servicesRestored
Orders: $ordersRestored
Order Items: $orderItemsRestored
Payments: $paymentsRestored
''';
}

/// Summary of data available in cloud
class CloudDataSummary {
  final bool available;
  final int customersCount;
  final int ordersCount;
  final int servicesCount;

  CloudDataSummary({
    required this.available,
    this.customersCount = 0,
    this.ordersCount = 0,
    this.servicesCount = 0,
  });

  bool get hasData => customersCount > 0 || ordersCount > 0 || servicesCount > 0;
}

/// Result of backup operation
class BackupResult {
  final bool success;
  final String message;
  final int outletsUploaded;
  final int settingsUploaded;
  final int usersUploaded;
  final int customersUploaded;
  final int servicesUploaded;
  final int ordersUploaded;
  final int orderItemsUploaded;
  final int paymentsUploaded;
  final String logs;

  BackupResult({
    required this.success,
    required this.message,
    this.outletsUploaded = 0,
    this.settingsUploaded = 0,
    this.usersUploaded = 0,
    this.customersUploaded = 0,
    this.servicesUploaded = 0,
    this.ordersUploaded = 0,
    this.orderItemsUploaded = 0,
    this.paymentsUploaded = 0,
    this.logs = '',
  });

  int get totalUploaded =>
      outletsUploaded +
      settingsUploaded +
      usersUploaded +
      customersUploaded +
      servicesUploaded +
      ordersUploaded +
      orderItemsUploaded +
      paymentsUploaded;

  String get summary => '''
Outlets: $outletsUploaded
Settings: $settingsUploaded
Users (Kasir): $usersUploaded
Customers: $customersUploaded
Services: $servicesUploaded
Orders: $ordersUploaded
Order Items: $orderItemsUploaded
Payments: $paymentsUploaded
''';
}

/// Summary of local data to be synced
class LocalDataSummary {
  final int outletsCount;
  final int customersCount;
  final int servicesCount;
  final int ordersCount;
  final int usersCount;

  LocalDataSummary({
    this.outletsCount = 0,
    this.customersCount = 0,
    this.servicesCount = 0,
    this.ordersCount = 0,
    this.usersCount = 0,
  });

  bool get hasData => outletsCount > 0 || customersCount > 0 || servicesCount > 0 || ordersCount > 0 || usersCount > 0;
  int get totalCount => outletsCount + customersCount + servicesCount + ordersCount + usersCount;
}
