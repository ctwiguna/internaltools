import 'package:flutter/foundation.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/customer.dart';

class CustomerRepository {
  final DatabaseHelper _databaseHelper;

  CustomerRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  bool get _isOnline => ConnectivityService.instance.isOnline;
  bool get _isAuthenticated => SupabaseService.instance.isAuthenticated;
  String? get _currentOutletIdStr => OutletService.instance.currentOutletIdStr;

  /// Get all customers for current outlet
  Future<List<Customer>> getAllCustomers() async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String? where;
    List<dynamic>? whereArgs;

    if (outletId != null) {
      where = 'outlet_id = ? OR outlet_id IS NULL';
      whereArgs = [outletId];
    }

    final result = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  /// Get customer by ID (with outlet validation)
  Future<Customer?> getCustomerById(int id) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String where = 'id = ?';
    List<dynamic> whereArgs = [id];

    // Validate customer belongs to current outlet
    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [id, outletId];
    }

    final result = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
    );
    if (result.isEmpty) return null;
    return Customer.fromMap(result.first);
  }

  /// Search customers by name or phone (within current outlet)
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String where = 'name LIKE ? OR phone LIKE ?';
    List<dynamic> whereArgs = ['%$query%', '%$query%'];

    if (outletId != null) {
      where = '(name LIKE ? OR phone LIKE ?) AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = ['%$query%', '%$query%', outletId];
    }

    final result = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  /// Create new customer
  Future<Customer> createCustomer(Customer customer) async {
    final db = await _databaseHelper.database;

    if (customer.name.trim().isEmpty) {
      throw Exception('Nama customer tidak boleh kosong');
    }

    // Check phone uniqueness if provided
    if (customer.phone != null && customer.phone!.isNotEmpty) {
      final existing = await getCustomerByPhone(customer.phone!);
      if (existing != null) {
        throw Exception('Nomor HP sudah terdaftar');
      }
    }

    final now = DateTime.now().toIso8601String();
    final outletId = _currentOutletIdStr;

    final id = await db.insert('customers', {
      'name': customer.name.trim(),
      'phone': customer.phone?.trim(),
      'address': customer.address?.trim(),
      'notes': customer.notes?.trim(),
      'outlet_id': outletId,
      'total_orders': 0,
      'total_spent': 0,
      'created_at': now,
      'updated_at': now,
    });

    final createdCustomer = customer.copyWith(
      id: id,
      totalOrders: 0,
      totalSpent: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Sync to Supabase
    await _syncCustomerCreate(createdCustomer);

    return createdCustomer;
  }

  Future<void> _syncCustomerCreate(Customer customer) async {
    if (!_isAuthenticated) return;

    final data = {
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address,
      'notes': customer.notes,
      'local_id': customer.id,
    };

    if (_isOnline) {
      try {
        final outletId = await _getOutletId();
        if (outletId == null) return;

        // Check if already exists by phone
        if (customer.phone != null && customer.phone!.isNotEmpty) {
          final existing = await SupabaseService.instance.client
              .from('customers')
              .select('id')
              .eq('outlet_id', outletId)
              .eq('phone', customer.phone!)
              .maybeSingle();

          if (existing != null) {
            // Update local with remote_id
            final db = await _databaseHelper.database;
            await db.update(
              'customers',
              {'remote_id': existing['id']},
              where: 'id = ?',
              whereArgs: [customer.id],
            );
            debugPrint('Sync: Customer already exists, linked remote_id');
            return;
          }
        }

        data['outlet_id'] = outletId;
        data.remove('local_id');
        final result = await SupabaseService.instance.insert('customers', data);

        // Update local with remote_id
        final db = await _databaseHelper.database;
        await db.update(
          'customers',
          {'remote_id': result['id']},
          where: 'id = ?',
          whereArgs: [customer.id],
        );
        debugPrint('Sync: Customer created and synced');
      } catch (e) {
        debugPrint('Sync customer error: $e');
        await _queueCustomerSync(customer.id!, data, SyncAction.insert);
      }
    } else {
      await _queueCustomerSync(customer.id!, data, SyncAction.insert);
    }
  }

  Future<String?> _getOutletId() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return null;
      final profile = await SupabaseService.instance.client
          .from('profiles')
          .select('outlet_id')
          .eq('id', userId)
          .single();
      return profile['outlet_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> _queueCustomerSync(int localId, Map<String, dynamic> data, SyncAction action) async {
    await SyncService.instance.queueForSync(
      table: 'customers',
      localId: localId,
      action: action,
      data: data,
    );
    debugPrint('Sync: Customer queued for sync');
  }

  /// Update customer (with outlet validation)
  Future<Customer> updateCustomer(Customer customer) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    if (customer.id == null) {
      throw Exception('Customer ID tidak ditemukan');
    }

    if (customer.name.trim().isEmpty) {
      throw Exception('Nama customer tidak boleh kosong');
    }

    // Check phone uniqueness if provided (excluding current customer)
    if (customer.phone != null && customer.phone!.isNotEmpty) {
      final existing = await getCustomerByPhone(customer.phone!);
      if (existing != null && existing.id != customer.id) {
        throw Exception('Nomor HP sudah terdaftar');
      }
    }

    // Build where clause with outlet validation
    String where = 'id = ?';
    List<dynamic> whereArgs = [customer.id];

    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [customer.id, outletId];
    }

    final now = DateTime.now().toIso8601String();
    final updateCount = await db.update(
      'customers',
      {
        'name': customer.name.trim(),
        'phone': customer.phone?.trim(),
        'address': customer.address?.trim(),
        'notes': customer.notes?.trim(),
        'updated_at': now,
      },
      where: where,
      whereArgs: whereArgs,
    );

    // If no rows updated, customer doesn't belong to current outlet
    if (updateCount == 0) {
      throw Exception('Customer tidak ditemukan di outlet ini');
    }

    // Sync update to Supabase
    await _syncCustomerUpdate(customer);

    return customer.copyWith(updatedAt: DateTime.now());
  }

  Future<void> _syncCustomerUpdate(Customer customer) async {
    if (!_isAuthenticated) return;

    // Get remote_id
    final db = await _databaseHelper.database;
    final result = await db.query(
      'customers',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [customer.id],
    );

    final remoteId = result.isNotEmpty ? result.first['remote_id'] as String? : null;
    if (remoteId == null) return;

    final data = {
      'remote_id': remoteId,
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address,
      'notes': customer.notes,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (_isOnline) {
      try {
        await SupabaseService.instance.client
            .from('customers')
            .update(data..remove('remote_id'))
            .eq('id', remoteId);
        debugPrint('Sync: Customer updated');
      } catch (e) {
        debugPrint('Sync customer update error: $e');
        await _queueCustomerSync(customer.id!, data, SyncAction.update);
      }
    } else {
      await _queueCustomerSync(customer.id!, data, SyncAction.update);
    }
  }

  /// Get customer by phone (within current outlet)
  Future<Customer?> getCustomerByPhone(String phone) async {
    final db = await _databaseHelper.database;
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;

    final outletId = _currentOutletIdStr;

    String where = "REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '+', '') = ?";
    List<dynamic> whereArgs = [cleaned];

    if (outletId != null) {
      where = "$where AND (outlet_id = ? OR outlet_id IS NULL)";
      whereArgs.add(outletId);
    }

    final result = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
    );
    if (result.isEmpty) return null;
    return Customer.fromMap(result.first);
  }

  /// Get or create customer by name (when no phone provided, within current outlet)
  /// If exact name exists, return existing customer
  /// If not, create new customer
  Future<Customer> getOrCreateByName({
    required String name,
  }) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    // Check if customer with this exact name exists in current outlet
    String where = 'LOWER(name) = LOWER(?)';
    List<dynamic> whereArgs = [name.trim()];

    if (outletId != null) {
      where = '$where AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs.add(outletId);
    }

    final result = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Customer.fromMap(result.first);
    }

    // Create new customer with outlet_id
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('customers', {
      'name': name.trim(),
      'phone': null,
      'outlet_id': outletId,
      'total_orders': 0,
      'total_spent': 0,
      'created_at': now,
      'updated_at': now,
    });

    return Customer(
      id: id,
      name: name.trim(),
      totalOrders: 0,
      totalSpent: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Get or create customer by phone (phone is unique per outlet)
  /// If phone exists in current outlet, update name if different and return existing customer
  /// If phone doesn't exist, create new customer
  Future<Customer> getOrCreateByPhone({
    required String name,
    required String phone,
  }) async {
    final db = await _databaseHelper.database;
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final outletId = _currentOutletIdStr;

    if (cleanedPhone.isEmpty) {
      throw Exception('Nomor HP tidak boleh kosong');
    }

    // Check if customer with this phone exists (getCustomerByPhone already filters by outlet)
    final existing = await getCustomerByPhone(cleanedPhone);

    if (existing != null) {
      // Update name if different
      if (existing.name != name.trim()) {
        await db.update(
          'customers',
          {
            'name': name.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        return existing.copyWith(name: name.trim());
      }
      return existing;
    }

    // Create new customer with outlet_id
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('customers', {
      'name': name.trim(),
      'phone': cleanedPhone,
      'outlet_id': outletId,
      'total_orders': 0,
      'total_spent': 0,
      'created_at': now,
      'updated_at': now,
    });

    return Customer(
      id: id,
      name: name.trim(),
      phone: cleanedPhone,
      totalOrders: 0,
      totalSpent: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Delete customer (with outlet validation)
  Future<void> deleteCustomer(int id) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    // Build where clause with outlet validation
    String where = 'id = ?';
    List<dynamic> whereArgs = [id];

    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [id, outletId];
    }

    // Get remote_id before deleting (with outlet validation)
    final result = await db.query(
      'customers',
      columns: ['remote_id'],
      where: where,
      whereArgs: whereArgs,
    );

    // If customer doesn't exist or doesn't belong to current outlet, return
    if (result.isEmpty) return;

    final remoteId = result.first['remote_id'] as String?;

    // Delete locally
    await db.delete(
      'customers',
      where: where,
      whereArgs: whereArgs,
    );

    // Sync delete to Supabase
    if (remoteId != null && _isAuthenticated) {
      if (_isOnline) {
        try {
          await SupabaseService.instance.client
              .from('customers')
              .delete()
              .eq('id', remoteId);
          debugPrint('Sync: Customer deleted from Supabase');
        } catch (e) {
          debugPrint('Sync customer delete error: $e');
          await _queueCustomerSync(id, {'remote_id': remoteId}, SyncAction.delete);
        }
      } else {
        await _queueCustomerSync(id, {'remote_id': remoteId}, SyncAction.delete);
      }
    }
  }

  /// Update customer order stats (called after order creation)
  Future<void> updateCustomerStats({
    required int customerId,
    required int orderAmount,
  }) async {
    final db = await _databaseHelper.database;

    final customer = await getCustomerById(customerId);
    if (customer == null) return;

    await db.update(
      'customers',
      {
        'total_orders': customer.totalOrders + 1,
        'total_spent': customer.totalSpent + orderAmount,
        'last_order_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Get top customers by total spent (within current outlet)
  Future<List<Customer>> getTopCustomers({int limit = 10}) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String? where;
    List<dynamic>? whereArgs;

    if (outletId != null) {
      where = 'outlet_id = ? OR outlet_id IS NULL';
      whereArgs = [outletId];
    }

    final result = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'total_spent DESC',
      limit: limit,
    );
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  /// Get customer count (within current outlet)
  Future<int> getCustomerCount() async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String query = 'SELECT COUNT(*) as count FROM customers';
    List<dynamic> args = [];

    if (outletId != null) {
      query = '$query WHERE outlet_id = ? OR outlet_id IS NULL';
      args.add(outletId);
    }

    final result = await db.rawQuery(query, args);
    return result.first['count'] as int;
  }
}
