import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/datasources/local/local_datasource.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

enum SyncAction {
  insert,
  update,
  delete,
}

/// Service to handle data synchronization between local SQLite and Supabase
class SyncService {
  SyncService._();

  static final SyncService _instance = SyncService._();
  static SyncService get instance => _instance;

  final ConnectivityService _connectivity = ConnectivityService.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final LocalDatasource _local = LocalDatasource();

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  /// Current sync status
  SyncStatus get status => _status;

  /// Last error message
  String? get lastError => _lastError;

  /// Last successful sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Stream of sync status changes
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Stream of sync errors
  Stream<String> get errorStream => _errorController.stream;

  /// Whether sync is currently in progress
  bool get isSyncing => _isSyncing;

  Timer? _periodicSyncTimer;

  /// Initialize sync service and setup listeners
  Future<void> initialize() async {
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((isOnline) {
      debugPrint('SyncService: Connectivity changed - isOnline: $isOnline');
      if (isOnline) {
        // Auto-sync when coming back online
        debugPrint('SyncService: Triggering auto-sync after reconnect');
        syncAll();
      }
    });

    // Setup periodic sync every 30 seconds when online
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connectivity.isOnline && _supabase.isAuthenticated && !_isSyncing) {
        syncAll();
      }
    });

    // Initial sync if online
    if (_connectivity.isOnline && _supabase.isAuthenticated) {
      syncAll();
    }
  }

  /// Queue a local change for sync
  Future<void> queueForSync({
    required String table,
    required int localId,
    required SyncAction action,
    required Map<String, dynamic> data,
  }) async {
    await _local.addToSyncQueue(
      tableName: table,
      recordId: localId,
      action: action.name.toUpperCase(),
      data: data,
    );

    // Try to sync immediately if online
    if (_connectivity.isOnline && !_isSyncing) {
      syncAll();
    }
  }

  /// Sync all pending changes
  Future<bool> syncAll() async {
    debugPrint('SyncService: syncAll called - isSyncing: $_isSyncing, isOnline: ${_connectivity.isOnline}, isAuth: ${_supabase.isAuthenticated}');
    if (_isSyncing) {
      debugPrint('SyncService: Already syncing, skipping');
      return false;
    }
    if (!_connectivity.isOnline) {
      debugPrint('SyncService: Offline, skipping sync');
      return false;
    }
    if (!_supabase.isAuthenticated) {
      debugPrint('SyncService: Not authenticated, skipping sync');
      return false;
    }

    debugPrint('SyncService: Starting sync...');
    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      // 1. Push local changes to remote
      await _pushLocalChanges();

      // 2. Pull remote changes (not implemented yet - would need timestamp tracking)
      // await _pullRemoteChanges();

      _lastSyncTime = DateTime.now();
      _lastError = null;
      _updateStatus(SyncStatus.success);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _updateStatus(SyncStatus.error);
      _errorController.add(e.toString());
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Push local changes to Supabase
  Future<void> _pushLocalChanges() async {
    final pendingItems = await _local.getPendingSyncItems();
    debugPrint('Sync: Found ${pendingItems.length} pending items');

    if (pendingItems.isEmpty) return;

    // Get outlet_id for the current user
    String? outletId;
    try {
      final userId = _supabase.currentUser?.id;
      if (userId != null) {
        final profile = await _supabase.client
            .from('profiles')
            .select('outlet_id')
            .eq('id', userId)
            .single();
        outletId = profile['outlet_id'] as String?;
      }
    } catch (e) {
      debugPrint('Sync: Error getting outlet_id: $e');
      return;
    }

    if (outletId == null) {
      debugPrint('Sync: No outlet_id found, skipping sync');
      return;
    }

    // Maps to track local_id -> remote_id relationships
    final customerIdMap = <int, String>{};
    final orderIdMap = <int, String>{};

    for (final item in pendingItems) {
      try {
        final table = item['table_name'] as String;
        final action = item['operation'] as String;
        final dataStr = item['data'] as String?;

        debugPrint('Sync: Processing $action on $table');

        if (dataStr == null || dataStr.isEmpty) {
          debugPrint('Sync: No data for item ${item['id']}, skipping');
          await _local.markSynced(item['id'] as int);
          continue;
        }

        // Parse the JSON data
        Map<String, dynamic>? data;
        try {
          data = json.decode(dataStr);
        } catch (e) {
          debugPrint('Sync: JSON parse error: $e');
          debugPrint('Sync: Data was: $dataStr');
          await _local.markSynced(item['id'] as int);
          continue;
        }

        if (data == null) {
          await _local.markSynced(item['id'] as int);
          continue;
        }

        switch (action) {
          case 'INSERT':
            if (table == 'customers') {
              // Handle customer sync
              final localId = data['local_id'] as int?;
              final localOutletIdStr = data['local_outlet_id'] as String?;
              data.remove('local_id');
              data.remove('local_outlet_id');

              // Determine correct outlet_id for this customer
              String? customerOutletId = outletId; // Default to user's current outlet
              if (localOutletIdStr != null) {
                // Lookup remote outlet_id from local outlet
                final outletData = await _local.rawQuery(
                  'SELECT remote_id FROM outlets WHERE id = ?',
                  [int.tryParse(localOutletIdStr) ?? 0],
                );
                if (outletData.isNotEmpty && outletData.first['remote_id'] != null) {
                  customerOutletId = outletData.first['remote_id'] as String;
                  debugPrint('Sync: Customer using outlet remote_id: $customerOutletId');
                }
              }
              data['outlet_id'] = customerOutletId;

              // Check if customer already exists by phone
              final phone = data['phone'] as String?;
              if (phone != null && phone.isNotEmpty && customerOutletId != null) {
                final existing = await _supabase.client
                    .from('customers')
                    .select('id')
                    .eq('outlet_id', customerOutletId)
                    .eq('phone', phone)
                    .maybeSingle();

                if (existing != null) {
                  final remoteId = existing['id'] as String;
                  if (localId != null) {
                    customerIdMap[localId] = remoteId;
                    // Update local customer with remote_id
                    await _local.rawExecute(
                      'UPDATE customers SET remote_id = ? WHERE id = ?',
                      [remoteId, localId],
                    );
                  }
                  debugPrint('Sync: Customer already exists, updated local remote_id');
                  await _local.markSynced(item['id'] as int);
                  continue;
                }
              }

              final result = await _supabase.insert(table, data);
              if (localId != null && result['id'] != null) {
                customerIdMap[localId] = result['id'] as String;
                // Update local customer with remote_id
                await _local.rawExecute(
                  'UPDATE customers SET remote_id = ? WHERE id = ?',
                  [result['id'], localId],
                );
              }
              debugPrint('Sync: Customer synced');
            } else if (table == 'orders') {
              // Handle order sync
              final localId = data['local_id'] as int?;
              final localCustomerId = data['local_customer_id'] as int?;
              final localOutletId = data['local_outlet_id'] as String?;
              final invoiceNo = data['invoice_no'] as String?;
              data.remove('local_id');
              data.remove('local_customer_id');
              data.remove('local_outlet_id');

              // Determine correct outlet_id for this order
              String? orderOutletId = outletId; // Default to user's current outlet
              if (localOutletId != null) {
                // Lookup remote outlet_id from local outlet
                final outletData = await _local.rawQuery(
                  'SELECT remote_id FROM outlets WHERE id = ?',
                  [int.tryParse(localOutletId) ?? 0],
                );
                if (outletData.isNotEmpty && outletData.first['remote_id'] != null) {
                  orderOutletId = outletData.first['remote_id'] as String;
                  debugPrint('Sync: Using outlet remote_id from local: $orderOutletId');
                }
              }
              data['outlet_id'] = orderOutletId;

              // Set customer_id from map or lookup from local database
              if (localCustomerId != null) {
                if (customerIdMap.containsKey(localCustomerId)) {
                  data['customer_id'] = customerIdMap[localCustomerId];
                } else {
                  // Check local database for customer's remote_id
                  final customerData = await _local.rawQuery(
                    'SELECT remote_id FROM customers WHERE id = ?',
                    [localCustomerId],
                  );
                  if (customerData.isNotEmpty && customerData.first['remote_id'] != null) {
                    final remoteCustomerId = customerData.first['remote_id'] as String;
                    customerIdMap[localCustomerId] = remoteCustomerId;
                    data['customer_id'] = remoteCustomerId;
                    debugPrint('Sync: Found customer remote_id from local DB: $remoteCustomerId');
                  } else if (orderOutletId != null) {
                    // Customer not synced yet, try to find by phone in Supabase
                    final customerLocalData = await _local.rawQuery(
                      'SELECT phone FROM customers WHERE id = ?',
                      [localCustomerId],
                    );
                    if (customerLocalData.isNotEmpty) {
                      final phone = customerLocalData.first['phone'] as String?;
                      if (phone != null && phone.isNotEmpty) {
                        final existing = await _supabase.client
                            .from('customers')
                            .select('id')
                            .eq('outlet_id', orderOutletId)
                            .eq('phone', phone)
                            .maybeSingle();
                        if (existing != null) {
                          final remoteCustomerId = existing['id'] as String;
                          customerIdMap[localCustomerId] = remoteCustomerId;
                          data['customer_id'] = remoteCustomerId;
                          // Update local customer with remote_id
                          await _local.rawExecute(
                            'UPDATE customers SET remote_id = ? WHERE id = ?',
                            [remoteCustomerId, localCustomerId],
                          );
                          debugPrint('Sync: Found customer in Supabase by phone: $remoteCustomerId');
                        }
                      }
                    }
                  }
                }
              }

              // Check if order already exists in Supabase by invoice_no
              String? remoteId;
              if (invoiceNo != null && orderOutletId != null) {
                final existing = await _supabase.client
                    .from('orders')
                    .select('id')
                    .eq('outlet_id', orderOutletId)
                    .eq('invoice_no', invoiceNo)
                    .maybeSingle();
                if (existing != null) {
                  remoteId = existing['id'] as String?;
                }
              }

              if (remoteId != null) {
                // Order already exists, just update local with remote_id
                if (localId != null) {
                  orderIdMap[localId] = remoteId;
                  await _local.rawExecute(
                    'UPDATE orders SET remote_id = ? WHERE id = ?',
                    [remoteId, localId],
                  );
                }
                debugPrint('Sync: Order already exists, updated remote_id');
              } else {
                // Insert new order
                final result = await _supabase.insert(table, data);
                if (localId != null && result['id'] != null) {
                  orderIdMap[localId] = result['id'] as String;

                  // Update local order with remote_id
                  await _local.rawExecute(
                    'UPDATE orders SET remote_id = ? WHERE id = ?',
                    [result['id'], localId],
                  );
                }
                debugPrint('Sync: Order synced');
              }
            } else if (table == 'order_items') {
              // Handle order items sync
              final localOrderId = data['local_order_id'] as int?;
              final localServiceId = data['local_service_id'] as int?;
              data.remove('local_order_id');
              data.remove('local_service_id');

              // Set order_id from map if available
              String? remoteOrderId;
              if (localOrderId != null) {
                if (orderIdMap.containsKey(localOrderId)) {
                  remoteOrderId = orderIdMap[localOrderId];
                } else {
                  // Check local database for remote_id
                  final orderData = await _local.rawQuery(
                    'SELECT remote_id FROM orders WHERE id = ?',
                    [localOrderId],
                  );
                  if (orderData.isNotEmpty && orderData.first['remote_id'] != null) {
                    remoteOrderId = orderData.first['remote_id'] as String;
                    orderIdMap[localOrderId] = remoteOrderId;
                  }
                }
              }

              // Set service_id from local database
              String? remoteServiceId;
              final serviceName = data['service_name'] as String?;

              // First, get the order's outlet_id to find the correct service
              String? orderOutletId = outletId; // Default to user's current outlet
              if (localOrderId != null) {
                final orderOutletData = await _local.rawQuery(
                  'SELECT outlet_id FROM orders WHERE id = ?',
                  [localOrderId],
                );
                if (orderOutletData.isNotEmpty) {
                  final localOutletIdStr = orderOutletData.first['outlet_id'] as String?;
                  if (localOutletIdStr != null) {
                    // Get remote outlet_id
                    final outletData = await _local.rawQuery(
                      'SELECT remote_id FROM outlets WHERE id = ?',
                      [int.tryParse(localOutletIdStr) ?? 0],
                    );
                    if (outletData.isNotEmpty && outletData.first['remote_id'] != null) {
                      orderOutletId = outletData.first['remote_id'] as String;
                    }
                  }
                }
              }

              if (localServiceId != null) {
                final serviceData = await _local.rawQuery(
                  'SELECT remote_id FROM services WHERE id = ?',
                  [localServiceId],
                );
                if (serviceData.isNotEmpty && serviceData.first['remote_id'] != null) {
                  remoteServiceId = serviceData.first['remote_id'] as String;
                  debugPrint('Sync: Found service remote_id from local DB: $remoteServiceId');
                }
              }

              // Fallback: find service by name in Supabase using order's outlet_id
              if (remoteServiceId == null && serviceName != null && orderOutletId != null) {
                try {
                  final existingService = await _supabase.client
                      .from('services')
                      .select('id')
                      .eq('outlet_id', orderOutletId)
                      .eq('name', serviceName)
                      .maybeSingle();
                  if (existingService != null) {
                    remoteServiceId = existingService['id'] as String;
                    debugPrint('Sync: Found service in Supabase by name: $remoteServiceId (outlet: $orderOutletId)');

                    // Update local service with remote_id for future syncs
                    if (localServiceId != null) {
                      await _local.rawExecute(
                        'UPDATE services SET remote_id = ? WHERE id = ?',
                        [remoteServiceId, localServiceId],
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('Sync: Error finding service by name: $e');
                }
              }

              if (remoteOrderId != null) {
                data['order_id'] = remoteOrderId;
                data['service_id'] = remoteServiceId; // Can be null if service not found
                await _supabase.insert(table, data);
                debugPrint('Sync: Order item synced with service_id: $remoteServiceId');
              } else {
                // FIX: parent order belum punya remote_id (misal insert order
                // gagal sesaat karena jaringan). JANGAN tandai synced —
                // biarkan di queue agar dicoba ulang di siklus berikutnya
                // setelah order induknya berhasil tersinkron.
                debugPrint('Sync: Order item deferred - parent order not yet synced, will retry');
                continue;
              }
            } else if (table == 'payments') {
              // Handle payment sync
              final localId = data['local_id'] as int?;
              final localOrderId = data['local_order_id'] as int?;
              data.remove('local_id');
              data.remove('local_order_id');

              // If order_id is already a remote UUID, use it
              // Otherwise check the map for local_order_id mapping
              String? remoteOrderId = data['order_id'] as String?;
              if (localOrderId != null) {
                if (orderIdMap.containsKey(localOrderId)) {
                  remoteOrderId = orderIdMap[localOrderId];
                } else {
                  // Check local database for remote_id
                  final orderData = await _local.rawQuery(
                    'SELECT remote_id FROM orders WHERE id = ?',
                    [localOrderId],
                  );
                  if (orderData.isNotEmpty && orderData.first['remote_id'] != null) {
                    remoteOrderId = orderData.first['remote_id'] as String;
                    orderIdMap[localOrderId] = remoteOrderId;
                  }
                }
              }

              if (remoteOrderId != null) {
                data['order_id'] = remoteOrderId;
                final result = await _supabase.insert(table, data);

                // Update local payment with remote_id
                if (localId != null && result['id'] != null) {
                  await _local.rawExecute(
                    'UPDATE payments SET remote_id = ? WHERE id = ?',
                    [result['id'], localId],
                  );
                }

                // Also update the order's paid amount in Supabase
                // Get current paid from local order and sync it
                if (localOrderId != null) {
                  final localOrder = await _local.rawQuery(
                    'SELECT paid FROM orders WHERE id = ?',
                    [localOrderId],
                  );
                  if (localOrder.isNotEmpty) {
                    final paidAmount = localOrder.first['paid'] as int? ?? 0;
                    await _supabase.update('orders', remoteOrderId, {
                      'paid': paidAmount,
                      'updated_at': DateTime.now().toIso8601String(),
                    });
                    debugPrint('Sync: Order paid amount updated to $paidAmount');
                  }
                }

                debugPrint('Sync: Payment synced');
              } else {
                // FIX: sama seperti order_items — jangan buang payment yang
                // parent order-nya belum tersinkron. Tetap di queue, retry.
                debugPrint('Sync: Payment deferred - parent order not yet synced, will retry');
                continue;
              }
            } else if (table == 'services') {
              // Handle service sync
              final localId = data['local_id'] as int?;
              data.remove('local_id');
              data['outlet_id'] = outletId;

              final result = await _supabase.insert(table, data);

              // Update local service with remote_id
              if (localId != null && result['id'] != null) {
                await _local.rawExecute(
                  'UPDATE services SET remote_id = ? WHERE id = ?',
                  [result['id'], localId],
                );
              }
              debugPrint('Sync: Service synced');
            } else if (table == 'attendance' ||
                table == 'shifts' ||
                table == 'cash_expenses' ||
                table == 'order_cancellation_requests') {
              // === MODUL INTERNAL (absen, shift, pengeluaran kas) ===
              // Baris-baris ini punya UUID yang dibuat di client (kolom 'id'),
              // jadi kita pakai UPSERT: aman di-retry, dan tutup shift cukup
              // meng-upsert ulang baris yang sama tanpa remapping remote_id.
              data.remove('local_id');
              final localOutletIdStr = data.remove('local_outlet_id') as String?;

              // Resolve outlet remote_id dari outlet lokal tempat kejadian,
              // JANGAN default ke outlet profil user (salah untuk multi-outlet).
              String? rowOutletId = outletId;
              if (localOutletIdStr != null) {
                final outletData = await _local.rawQuery(
                  'SELECT remote_id FROM outlets WHERE id = ?',
                  [int.tryParse(localOutletIdStr) ?? 0],
                );
                if (outletData.isNotEmpty &&
                    outletData.first['remote_id'] != null) {
                  rowOutletId = outletData.first['remote_id'] as String;
                }
              }
              if (rowOutletId == null) {
                // Outlet belum pernah di-backup ke cloud — tunda, jangan buang.
                debugPrint('Sync: $table deferred - outlet has no remote_id yet');
                continue;
              }
              data['outlet_id'] = rowOutletId;

              await _supabase.upsert(table, data);
              debugPrint('Sync: $table upserted (${data['id']})');
            } else {
              // Generic insert
              data['outlet_id'] = outletId;
              await _supabase.insert(table, data);
              debugPrint('Sync: Insert successful');
            }
            break;
          case 'UPDATE':
            final id = data['remote_id'] ?? data['id'];
            if (id != null) {
              data.remove('local_id');
              await _supabase.update(table, id.toString(), data);
            }
            break;
          case 'DELETE':
            final id = data['remote_id'] ?? data['id'];
            if (id != null) {
              await _supabase.delete(table, id.toString());
            }
            break;
        }

        // Mark as synced
        await _local.markSynced(item['id'] as int);
      } catch (e) {
        // Log error but continue with other items
        debugPrint('Sync error for item ${item['id']}: $e');
      }
    }

    // Clean up old synced items
    await _local.clearSyncedItems();
  }

  void _updateStatus(SyncStatus status) {
    _status = status;
    _statusController.add(status);
  }

  /// Get count of pending sync items
  Future<int> getPendingCount() async {
    final items = await _local.getPendingSyncItems();
    return items.length;
  }

  /// Force clear all pending sync items (use with caution)
  Future<void> clearPendingSync() async {
    await _local.rawExecute('DELETE FROM sync_queue');
  }

  void dispose() {
    _periodicSyncTimer?.cancel();
    _statusController.close();
    _errorController.close();
  }
}
