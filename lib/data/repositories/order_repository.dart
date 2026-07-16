import 'package:flutter/foundation.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/order.dart';
import 'package:flutter_laundry_offline_app/data/models/order_item.dart';
import 'package:flutter_laundry_offline_app/data/models/payment.dart';
import 'package:flutter_laundry_offline_app/data/repositories/customer_repository.dart';

class OrderRepository {
  final DatabaseHelper _databaseHelper;
  final CustomerRepository _customerRepository;

  OrderRepository({
    DatabaseHelper? databaseHelper,
    CustomerRepository? customerRepository,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _customerRepository = customerRepository ?? CustomerRepository();

  String? get _currentOutletIdStr => OutletService.instance.currentOutletIdStr;

  /// Get all orders with optional filter and pagination (filtered by current outlet)
  Future<List<Order>> getAllOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    // Filter by outlet
    if (outletId != null) {
      whereClauses.add('(outlet_id = ? OR outlet_id IS NULL)');
      whereArgs.add(outletId);
    }

    // Filter by status
    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.value);
    }

    String? where;
    if (whereClauses.isNotEmpty) {
      where = whereClauses.join(' AND ');
    }

    final result = await db.query(
      'orders',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((map) => Order.fromMap(map)).toList();
  }

  /// Get order by ID with items and payments (with outlet validation)
  Future<Order?> getOrderById(int id) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String where = 'id = ?';
    List<dynamic> whereArgs = [id];

    // Validate order belongs to current outlet
    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [id, outletId];
    }

    final orderResult = await db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
    );

    if (orderResult.isEmpty) return null;

    final order = Order.fromMap(orderResult.first);

    // Get items
    final itemsResult = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [id],
    );
    final items = itemsResult.map((map) => OrderItem.fromMap(map)).toList();

    // Get payments
    final paymentsResult = await db.query(
      'payments',
      where: 'order_id = ?',
      whereArgs: [id],
      orderBy: 'payment_date DESC',
    );
    final payments = paymentsResult.map((map) => Payment.fromMap(map)).toList();

    return order.copyWith(items: items, payments: payments);
  }

  /// Create new order with items
  Future<Order> createOrder({
    required Order order,
    required List<OrderItem> items,
    Payment? initialPayment,
  }) async {
    final db = await _databaseHelper.database;

    // Auto-save customer if phone is provided (before transaction)
    int? customerId = order.customerId;

    // Verify customer exists if customerId is provided
    if (customerId != null) {
      final existingCustomer = await _customerRepository.getCustomerById(customerId);
      if (existingCustomer == null) {
        customerId = null; // Reset if customer doesn't exist
      }
    }

    // Create or get customer by phone if provided
    if (order.customerPhone != null && order.customerPhone!.isNotEmpty) {
      try {
        final customer = await _customerRepository.getOrCreateByPhone(
          name: order.customerName,
          phone: order.customerPhone!,
        );
        customerId = customer.id;
      } catch (_) {
        // Ignore customer creation errors, continue with order
      }
    }

    // Create order in transaction
    final createdOrder = await db.transaction((txn) async {
      // Insert order
      final now = DateTime.now().toIso8601String();
      final outletId = _currentOutletIdStr;

      final orderId = await txn.insert('orders', {
        'invoice_no': order.invoiceNo,
        'customer_id': customerId,
        'customer_name': order.customerName,
        'customer_phone': order.customerPhone,
        'order_date': order.orderDate.toIso8601String(),
        'due_date': order.dueDate?.toIso8601String(),
        'status': order.status.value,
        'total_items': order.totalItems,
        'total_weight': order.totalWeight,
        'total_price': order.totalPrice,
        'paid': order.paid,
        'notes': order.notes,
        'outlet_id': outletId,
        'created_by': order.createdBy,
        'created_at': now,
        'updated_at': now,
      });

      // Insert items
      for (final item in items) {
        await txn.insert('order_items', {
          'order_id': orderId,
          'service_id': item.serviceId,
          'service_name': item.serviceName,
          'quantity': item.quantity,
          'unit': item.unit,
          'price_per_unit': item.pricePerUnit,
          'subtotal': item.subtotal,
        });
      }

      // Insert initial payment if provided
      if (initialPayment != null && initialPayment.amount > 0) {
        await txn.insert('payments', {
          'order_id': orderId,
          'amount': initialPayment.amount,
          'change': initialPayment.change,
          'payment_date': initialPayment.paymentDate.toIso8601String(),
          'payment_method': initialPayment.paymentMethod.value,
          'notes': initialPayment.notes,
          'received_by': initialPayment.receivedBy,
          'created_at': now,
        });

        // Update paid amount in order (amount - change = actual paid)
        final actualPaid = initialPayment.amount - initialPayment.change;
        final newPaid = actualPaid > order.totalPrice ? order.totalPrice : actualPaid;
        await txn.update(
          'orders',
          {'paid': newPaid},
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }

      return order.copyWith(id: orderId, customerId: customerId);
    });

    // Update customer stats AFTER transaction completes (to avoid deadlock)
    if (customerId != null) {
      try {
        await _customerRepository.updateCustomerStats(
          customerId: customerId,
          orderAmount: order.totalPrice,
        );
      } catch (_) {
        // Ignore stats update errors
      }
    }

    // Sync to Supabase in background - don't block UI
    final isOnline = ConnectivityService.instance.isOnline;
    final isAuthenticated = SupabaseService.instance.isAuthenticated;

    if (isAuthenticated) {
      // Queue for sync - will be processed by SyncService
      debugPrint('Sync: Queuing order for sync (online: $isOnline)');
      await _queueOrderForSync(createdOrder, items, customerId);

      // Trigger sync immediately if online (non-blocking)
      if (isOnline) {
        // Don't await - let it run in background
        SyncService.instance.syncAll();
      }
    }

    return createdOrder;
  }

  /// Queue order for sync when back online
  Future<void> _queueOrderForSync(
    Order order,
    List<OrderItem> items,
    int? customerId,
  ) async {
    try {
      // Get outlet_id from local order first
      final db = await _databaseHelper.database;
      final localOrder = await db.query(
        'orders',
        columns: ['outlet_id'],
        where: 'id = ?',
        whereArgs: [order.id],
      );
      final localOutletId = localOrder.isNotEmpty
          ? localOrder.first['outlet_id'] as String?
          : null;

      // Queue customer first if exists (with outlet_id)
      if (customerId != null) {
        final customer = await _customerRepository.getCustomerById(customerId);
        if (customer != null) {
          await SyncService.instance.queueForSync(
            table: 'customers',
            localId: customerId,
            action: SyncAction.insert,
            data: {
              'name': customer.name,
              'phone': customer.phone,
              'address': customer.address,
              'notes': customer.notes,
              'local_id': customerId,
              'local_outlet_id': localOutletId,
            },
          );
        }
      }

      // Queue order
      await SyncService.instance.queueForSync(
        table: 'orders',
        localId: order.id!,
        action: SyncAction.insert,
        data: {
          'invoice_no': order.invoiceNo,
          'customer_name': order.customerName,
          'customer_phone': order.customerPhone,
          'order_date': order.orderDate.toIso8601String(),
          'due_date': order.dueDate?.toIso8601String(),
          'status': order.status.value,
          'total_items': order.totalItems,
          'total_weight': order.totalWeight,
          'total_price': order.totalPrice,
          'paid': order.paid,
          'notes': order.notes,
          'local_id': order.id,
          'local_customer_id': customerId,
          'local_outlet_id': localOutletId,
        },
      );

      // Queue order items
      for (final item in items) {
        await SyncService.instance.queueForSync(
          table: 'order_items',
          localId: item.id ?? 0,
          action: SyncAction.insert,
          data: {
            'service_name': item.serviceName,
            'quantity': item.quantity,
            'unit': item.unit,
            'price_per_unit': item.pricePerUnit,
            'subtotal': item.subtotal,
            'local_order_id': order.id,
            'local_service_id': item.serviceId,
          },
        );
      }

      debugPrint('Sync: Order queued for later sync');
    } catch (e) {
      debugPrint('Sync queue error: $e');
    }
  }

  /// Update order status (with outlet validation)
  Future<void> updateOrderStatus(int id, OrderStatus newStatus) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    // Build where clause with outlet validation
    String where = 'id = ?';
    List<dynamic> whereArgs = [id];

    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [id, outletId];
    }

    final updateCount = await db.update(
      'orders',
      {
        'status': newStatus.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: where,
      whereArgs: whereArgs,
    );

    // If no rows updated, order doesn't belong to current outlet
    if (updateCount == 0) return;

    // Get order's remote_id
    final orderResult = await db.query(
      'orders',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [id],
    );

    final remoteId = orderResult.isNotEmpty
        ? orderResult.first['remote_id'] as String?
        : null;

    final isOnline = ConnectivityService.instance.isOnline;
    final isAuthenticated = SupabaseService.instance.isAuthenticated;

    if (isOnline && isAuthenticated && remoteId != null) {
      // Online: Sync directly
      try {
        await SupabaseService.instance.client.from('orders').update({
          'status': newStatus.value,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', remoteId);
        debugPrint('Sync: Order status updated to ${newStatus.value}');
      } catch (e) {
        debugPrint('Sync status error: $e');
        // Queue for later if direct sync fails
        await _queueStatusUpdate(id, remoteId, newStatus);
      }
    } else if (!isOnline && isAuthenticated && remoteId != null) {
      // Offline: Queue for sync
      await _queueStatusUpdate(id, remoteId, newStatus);
    }
  }

  Future<void> _queueStatusUpdate(int localId, String remoteId, OrderStatus status) async {
    await SyncService.instance.queueForSync(
      table: 'orders',
      localId: localId,
      action: SyncAction.update,
      data: {
        'remote_id': remoteId,
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
    debugPrint('Sync: Order status queued for sync');
  }

  /// Delete order (with outlet validation)
  Future<void> deleteOrder(int id) async {
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
    final orderResult = await db.query(
      'orders',
      columns: ['remote_id'],
      where: where,
      whereArgs: whereArgs,
    );

    // If order doesn't exist or doesn't belong to current outlet, return
    if (orderResult.isEmpty) return;

    final remoteId = orderResult.first['remote_id'] as String?;

    // Delete locally (items and payments will be cascade deleted)
    await db.delete(
      'orders',
      where: where,
      whereArgs: whereArgs,
    );

    // Sync delete to Supabase
    final isOnline = ConnectivityService.instance.isOnline;
    final isAuthenticated = SupabaseService.instance.isAuthenticated;

    if (remoteId != null && isAuthenticated) {
      if (isOnline) {
        try {
          await SupabaseService.instance.client
              .from('orders')
              .delete()
              .eq('id', remoteId);
          debugPrint('Sync: Order deleted from Supabase');
        } catch (e) {
          debugPrint('Sync delete error: $e');
          await _queueOrderDelete(id, remoteId);
        }
      } else {
        await _queueOrderDelete(id, remoteId);
      }
    }
  }

  Future<void> _queueOrderDelete(int localId, String remoteId) async {
    await SyncService.instance.queueForSync(
      table: 'orders',
      localId: localId,
      action: SyncAction.delete,
      data: {'remote_id': remoteId},
    );
    debugPrint('Sync: Order delete queued');
  }

  /// Search orders (filtered by current outlet)
  Future<List<Order>> searchOrders(String query) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String where = '(customer_name LIKE ? OR customer_phone LIKE ? OR invoice_no LIKE ?)';
    List<dynamic> whereArgs = ['%$query%', '%$query%', '%$query%'];

    if (outletId != null) {
      where = '$where AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs.add(outletId);
    }

    final result = await db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return result.map((map) => Order.fromMap(map)).toList();
  }

  /// Get orders by date range (filtered by current outlet)
  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    final startStr = DateTime(start.year, start.month, start.day).toIso8601String();
    final endStr = DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();

    String where = 'order_date >= ? AND order_date <= ?';
    List<dynamic> whereArgs = [startStr, endStr];

    if (outletId != null) {
      where = '$where AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs.add(outletId);
    }

    final result = await db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return result.map((map) => Order.fromMap(map)).toList();
  }

  /// Get orders by status count (filtered by current outlet)
  Future<Map<OrderStatus, int>> getOrderCountByStatus() async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    final counts = <OrderStatus, int>{};
    for (final status in OrderStatus.values) {
      String query = 'SELECT COUNT(*) as count FROM orders WHERE status = ?';
      List<dynamic> args = [status.value];

      if (outletId != null) {
        query = '$query AND (outlet_id = ? OR outlet_id IS NULL)';
        args.add(outletId);
      }

      final result = await db.rawQuery(query, args);
      counts[status] = result.first['count'] as int;
    }

    return counts;
  }

  /// Get all order count by status (for dashboard overview, filtered by current outlet)
  Future<Map<OrderStatus, int>> getTodayOrderCountByStatus() async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    final counts = <OrderStatus, int>{};
    for (final status in OrderStatus.values) {
      String query = 'SELECT COUNT(*) as count FROM orders WHERE status = ?';
      List<dynamic> args = [status.value];

      if (outletId != null) {
        query = '$query AND (outlet_id = ? OR outlet_id IS NULL)';
        args.add(outletId);
      }

      final result = await db.rawQuery(query, args);
      counts[status] = result.first['count'] as int;
    }

    return counts;
  }

  /// Get recent orders (filtered by current outlet)
  Future<List<Order>> getRecentOrders({int limit = 5}) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    String? where;
    List<dynamic>? whereArgs;

    if (outletId != null) {
      where = 'outlet_id = ? OR outlet_id IS NULL';
      whereArgs = [outletId];
    }

    final result = await db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return result.map((map) => Order.fromMap(map)).toList();
  }

  /// Update paid amount after payment (with outlet validation)
  Future<void> updatePaidAmount(int orderId, int newPaidAmount) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    // Build where clause with outlet validation
    String where = 'id = ?';
    List<dynamic> whereArgs = [orderId];

    if (outletId != null) {
      where = 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)';
      whereArgs = [orderId, outletId];
    }

    final updateCount = await db.update(
      'orders',
      {
        'paid': newPaidAmount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: where,
      whereArgs: whereArgs,
    );

    // If no rows updated, order doesn't belong to current outlet
    if (updateCount == 0) return;

    // Get order's remote_id
    final orderResult = await db.query(
      'orders',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [orderId],
    );

    final remoteId = orderResult.isNotEmpty
        ? orderResult.first['remote_id'] as String?
        : null;

    final isOnline = ConnectivityService.instance.isOnline;
    final isAuthenticated = SupabaseService.instance.isAuthenticated;

    if (isOnline && isAuthenticated && remoteId != null) {
      // Online: Sync directly
      try {
        await SupabaseService.instance.client.from('orders').update({
          'paid': newPaidAmount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', remoteId);
        debugPrint('Sync: Order paid amount updated to $newPaidAmount');
      } catch (e) {
        debugPrint('Sync paid amount error: $e');
        await _queuePaidAmountUpdate(orderId, remoteId, newPaidAmount);
      }
    } else if (!isOnline && isAuthenticated && remoteId != null) {
      // Offline: Queue for sync
      await _queuePaidAmountUpdate(orderId, remoteId, newPaidAmount);
    }
  }

  Future<void> _queuePaidAmountUpdate(int localId, String remoteId, int paidAmount) async {
    await SyncService.instance.queueForSync(
      table: 'orders',
      localId: localId,
      action: SyncAction.update,
      data: {
        'remote_id': remoteId,
        'paid': paidAmount,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
    debugPrint('Sync: Order paid amount queued for sync');
  }
}
