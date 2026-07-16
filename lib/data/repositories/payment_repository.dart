import 'package:flutter/foundation.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/payment.dart';

class PaymentRepository {
  final DatabaseHelper _databaseHelper;

  PaymentRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  bool get _isOnline => ConnectivityService.instance.isOnline;
  bool get _isAuthenticated => SupabaseService.instance.isAuthenticated;
  String? get _currentOutletIdStr => OutletService.instance.currentOutletIdStr;

  /// Get all payments for an order (with outlet validation)
  Future<List<Payment>> getPaymentsByOrderId(int orderId) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    // First validate that the order belongs to current outlet
    if (outletId != null) {
      final orderResult = await db.query(
        'orders',
        columns: ['id'],
        where: 'id = ? AND (outlet_id = ? OR outlet_id IS NULL)',
        whereArgs: [orderId, outletId],
      );
      // If order doesn't belong to current outlet, return empty
      if (orderResult.isEmpty) {
        return [];
      }
    }

    final result = await db.query(
      'payments',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'payment_date DESC',
    );

    return result.map((map) => Payment.fromMap(map)).toList();
  }

  /// Add payment and update order paid amount
  Future<Payment> addPayment(Payment payment) async {
    final db = await _databaseHelper.database;

    final createdPayment = await db.transaction((txn) async {
      // Insert payment
      final now = DateTime.now().toIso8601String();
      final paymentId = await txn.insert('payments', {
        'order_id': payment.orderId,
        'amount': payment.amount,
        'change': payment.change,
        'payment_date': payment.paymentDate.toIso8601String(),
        'payment_method': payment.paymentMethod.value,
        'notes': payment.notes,
        'received_by': payment.receivedBy,
        'created_at': now,
      });

      // Get current paid amount and total price
      final orderResult = await txn.query(
        'orders',
        columns: ['paid', 'total_price'],
        where: 'id = ?',
        whereArgs: [payment.orderId],
      );

      if (orderResult.isNotEmpty) {
        final currentPaid = orderResult.first['paid'] as int;
        final totalPrice = orderResult.first['total_price'] as int;

        // Hitung berapa yang masuk ke paid (dikurangi kembalian)
        final actualPaid = payment.amount - payment.change;
        var newPaid = currentPaid + actualPaid;

        // Pastikan tidak melebihi total price
        if (newPaid > totalPrice) {
          newPaid = totalPrice;
        }

        // Update order paid amount
        await txn.update(
          'orders',
          {
            'paid': newPaid,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [payment.orderId],
        );
      }

      return payment.copyWith(id: paymentId);
    });

    // Sync payment to Supabase
    await _syncPaymentCreate(createdPayment);

    return createdPayment;
  }

  Future<void> _syncPaymentCreate(Payment payment) async {
    if (!_isAuthenticated) return;

    final db = await _databaseHelper.database;

    // Get order's remote_id
    final orderResult = await db.query(
      'orders',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [payment.orderId],
    );

    final orderRemoteId = orderResult.isNotEmpty
        ? orderResult.first['remote_id'] as String?
        : null;

    if (orderRemoteId == null) {
      debugPrint('Sync: Payment skipped - no order remote_id');
      return;
    }

    final data = {
      'order_id': orderRemoteId,
      'amount': payment.amount,
      'change': payment.change,
      'payment_date': payment.paymentDate.toIso8601String(),
      'payment_method': payment.paymentMethod.value,
      'notes': payment.notes,
      'local_id': payment.id,
      'local_order_id': payment.orderId,
    };

    if (_isOnline) {
      try {
        final result = await SupabaseService.instance.insert('payments', {
          'order_id': orderRemoteId,
          'amount': payment.amount,
          'change': payment.change,
          'payment_date': payment.paymentDate.toIso8601String(),
          'payment_method': payment.paymentMethod.value,
          'notes': payment.notes,
        });

        // Update local with remote_id
        await db.update(
          'payments',
          {'remote_id': result['id']},
          where: 'id = ?',
          whereArgs: [payment.id],
        );
        debugPrint('Sync: Payment created and synced');
      } catch (e) {
        debugPrint('Sync payment error: $e');
        await _queuePaymentSync(payment.id!, data);
      }
    } else {
      await _queuePaymentSync(payment.id!, data);
    }
  }

  Future<void> _queuePaymentSync(int localId, Map<String, dynamic> data) async {
    await SyncService.instance.queueForSync(
      table: 'payments',
      localId: localId,
      action: SyncAction.insert,
      data: data,
    );
    debugPrint('Sync: Payment queued for sync');
  }

  /// Get total paid amount for an order
  Future<int> getTotalPaidAmount(int orderId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM payments WHERE order_id = ?',
      [orderId],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  /// Get payments by date range (filtered by outlet via orders)
  Future<List<Payment>> getPaymentsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    final startStr = DateTime(start.year, start.month, start.day).toIso8601String();
    final endStr = DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();

    String query = '''
      SELECT p.* FROM payments p
      INNER JOIN orders o ON o.id = p.order_id
      WHERE p.payment_date >= ? AND p.payment_date <= ?
    ''';
    List<dynamic> args = [startStr, endStr];

    if (outletId != null) {
      query = '$query AND (o.outlet_id = ? OR o.outlet_id IS NULL)';
      args.add(outletId);
    }

    query = '$query ORDER BY p.payment_date DESC';

    final result = await db.rawQuery(query, args);

    return result.map((map) => Payment.fromMap(map)).toList();
  }

  /// Get total revenue by date range (amount - change = actual revenue, filtered by outlet)
  Future<int> getTotalRevenueByDateRange(DateTime start, DateTime end) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    final startStr = DateTime(start.year, start.month, start.day).toIso8601String();
    final endStr = DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();

    String query = '''
      SELECT SUM(p.amount - p.change) as total
      FROM payments p
      INNER JOIN orders o ON o.id = p.order_id
      WHERE p.payment_date >= ? AND p.payment_date <= ?
    ''';
    List<dynamic> args = [startStr, endStr];

    if (outletId != null) {
      query = '$query AND (o.outlet_id = ? OR o.outlet_id IS NULL)';
      args.add(outletId);
    }

    final result = await db.rawQuery(query, args);

    return (result.first['total'] as int?) ?? 0;
  }

  /// Get today's total revenue
  Future<int> getTodayRevenue() async {
    final today = DateTime.now();
    return getTotalRevenueByDateRange(today, today);
  }

  /// Get revenue by payment method (amount - change = actual revenue, filtered by outlet)
  Future<Map<PaymentMethod, int>> getRevenueByPaymentMethod(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;

    final startStr = DateTime(start.year, start.month, start.day).toIso8601String();
    final endStr = DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();

    final revenue = <PaymentMethod, int>{};
    for (final method in PaymentMethod.values) {
      String query = '''
        SELECT SUM(p.amount - p.change) as total
        FROM payments p
        INNER JOIN orders o ON o.id = p.order_id
        WHERE p.payment_method = ? AND p.payment_date >= ? AND p.payment_date <= ?
      ''';
      List<dynamic> args = [method.value, startStr, endStr];

      if (outletId != null) {
        query = '$query AND (o.outlet_id = ? OR o.outlet_id IS NULL)';
        args.add(outletId);
      }

      final result = await db.rawQuery(query, args);
      revenue[method] = (result.first['total'] as int?) ?? 0;
    }

    return revenue;
  }

  /// Get this month's total order count (filtered by outlet)
  Future<int> getThisMonthOrderCount() async {
    final db = await _databaseHelper.database;
    final outletId = _currentOutletIdStr;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

    String query = 'SELECT COUNT(*) as count FROM orders WHERE created_at >= ? AND created_at <= ?';
    List<dynamic> args = [startOfMonth, endOfMonth];

    if (outletId != null) {
      query = '$query AND (outlet_id = ? OR outlet_id IS NULL)';
      args.add(outletId);
    }

    final result = await db.rawQuery(query, args);

    return result.first['count'] as int;
  }
}
