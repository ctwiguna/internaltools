import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/order.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_order_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/report/report_state.dart';

/// Repository laporan dari Supabase.
///
/// Menghitung ReportData yang sama persis seperti ReportRepository (SQLite),
/// tetapi dari data online dan SELALU terfilter outlet aktif
/// (OutletService.currentOutletUuid) — jadi laporan owner mengikuti
/// fitur switch outlet.
class SupabaseReportRepository {
  final SupabaseService _supabase;
  final SupabaseOrderRepository _orderRepository;

  SupabaseReportRepository({
    SupabaseService? supabase,
    SupabaseOrderRepository? orderRepository,
  })  : _supabase = supabase ?? SupabaseService.instance,
        _orderRepository = orderRepository ?? SupabaseOrderRepository();

  /// UUID outlet aktif (mengikuti switch outlet).
  String? get _outletUuid => OutletService.instance.currentOutletUuid;

  /// Get orders within date range for current outlet
  /// (delegasi ke SupabaseOrderRepository yang sudah terfilter outlet).
  Future<List<Order>> getOrdersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _orderRepository.getOrdersByDateRange(startDate, endDate);
  }

  /// Get report data for date range (filtered by current outlet)
  Future<ReportData> getReportData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    final uuid = _outletUuid;

    // ---------------------------------------------------------------
    // 1. Orders dalam rentang tanggal (by order_date, filter outlet)
    // ---------------------------------------------------------------
    var ordersQuery = _supabase.client
        .from('orders')
        .select()
        .gte('order_date', startStr)
        .lte('order_date', endStr);
    if (uuid != null) ordersQuery = ordersQuery.eq('outlet_id', uuid);
    final ordersData = await ordersQuery;

    final orders = (ordersData as List)
        .map((map) => Order.fromSupabase(map as Map<String, dynamic>))
        .toList();

    final totalOrders = orders.length;
    final totalRevenue =
        orders.fold<int>(0, (sum, o) => sum + o.totalPrice);
    final totalUnpaid = orders.fold<int>(
        0, (sum, o) => sum + (o.totalPrice - o.paid));

    // Orders by status
    final ordersByStatus = <OrderStatus, int>{};
    int completedOrders = 0;
    int pendingOrders = 0;
    for (final order in orders) {
      ordersByStatus[order.status] = (ordersByStatus[order.status] ?? 0) + 1;
      if (order.status == OrderStatus.done) {
        completedOrders++;
      } else {
        pendingOrders++;
      }
    }

    // Daily revenue dari orders (by order_date, tanggal lokal)
    final dailyOrders = <String, _DailyOrderAgg>{};
    for (final order in orders) {
      final key = _dateKey(order.orderDate.toLocal());
      final agg = dailyOrders.putIfAbsent(key, () => _DailyOrderAgg());
      agg.revenue += order.totalPrice;
      agg.orderCount += 1;
    }

    // ---------------------------------------------------------------
    // 2. Payments dalam rentang tanggal (by payment_date,
    //    filter outlet lewat orders!inner)
    // ---------------------------------------------------------------
    var paymentsQuery = _supabase.client
        .from('payments')
        .select('amount, change_amount, payment_date, orders!inner(outlet_id)')
        .gte('payment_date', startStr)
        .lte('payment_date', endStr);
    if (uuid != null) {
      paymentsQuery = paymentsQuery.eq('orders.outlet_id', uuid);
    }
    final paymentsData = await paymentsQuery;

    int totalPaid = 0;
    final dailyPayments = <String, int>{};
    for (final row in paymentsData as List) {
      final amount = (row['amount'] as num?)?.toInt() ?? 0;
      final change = (row['change_amount'] as num?)?.toInt() ?? 0;
      final net = amount - change;
      totalPaid += net;

      final paymentDateStr = row['payment_date'] as String?;
      if (paymentDateStr != null) {
        final key = _dateKey(DateTime.parse(paymentDateStr).toLocal());
        dailyPayments[key] = (dailyPayments[key] ?? 0) + net;
      }
    }

    // Gabungkan daily orders + payments (mirip logika repo lokal)
    final dailyRevenue = <DailyRevenue>[];
    dailyOrders.forEach((key, agg) {
      dailyRevenue.add(DailyRevenue(
        date: DateTime.parse(key),
        revenue: agg.revenue,
        orderCount: agg.orderCount,
        paid: dailyPayments[key] ?? 0,
      ));
    });
    // Tambahkan hari yang punya payment tapi tidak punya order
    for (final entry in dailyPayments.entries) {
      final exists = dailyRevenue.any(
        (d) => _dateKey(d.date) == entry.key,
      );
      if (!exists && entry.value > 0) {
        dailyRevenue.add(DailyRevenue(
          date: DateTime.parse(entry.key),
          revenue: 0,
          orderCount: 0,
          paid: entry.value,
        ));
      }
    }
    dailyRevenue.sort((a, b) => a.date.compareTo(b.date));

    // ---------------------------------------------------------------
    // 3. Top services (order_items join orders, filter tanggal+outlet)
    // ---------------------------------------------------------------
    var itemsQuery = _supabase.client.from('order_items').select(
        'order_id, service_name, quantity, subtotal, orders!inner(order_date, outlet_id)')
        .gte('orders.order_date', startStr)
        .lte('orders.order_date', endStr);
    if (uuid != null) {
      itemsQuery = itemsQuery.eq('orders.outlet_id', uuid);
    }
    final itemsData = await itemsQuery;

    final serviceAgg = <String, _ServiceAgg>{};
    for (final row in itemsData as List) {
      final name = row['service_name'] as String? ?? '-';
      final agg = serviceAgg.putIfAbsent(name, () => _ServiceAgg());
      agg.totalQuantity += (row['quantity'] as num?)?.toDouble() ?? 0;
      agg.totalRevenue += (row['subtotal'] as num?)?.toInt() ?? 0;
      final orderId = row['order_id'] as String?;
      if (orderId != null) agg.orderIds.add(orderId);
    }

    final topServices = serviceAgg.entries
        .map((e) => ServiceSummary(
              serviceName: e.key,
              totalQuantity: e.value.totalQuantity.round(),
              totalRevenue: e.value.totalRevenue,
              orderCount: e.value.orderIds.length,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final top10 = topServices.take(10).toList();

    return ReportData(
      startDate: startDate,
      endDate: endDate,
      totalOrders: totalOrders,
      completedOrders: completedOrders,
      pendingOrders: pendingOrders,
      totalRevenue: totalRevenue,
      totalPaid: totalPaid,
      totalUnpaid: totalUnpaid,
      ordersByStatus: ordersByStatus,
      dailyRevenue: dailyRevenue,
      topServices: top10,
    );
  }

  /// Key tanggal "YYYY-MM-DD" (waktu lokal).
  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _DailyOrderAgg {
  int revenue = 0;
  int orderCount = 0;
}

class _ServiceAgg {
  double totalQuantity = 0;
  int totalRevenue = 0;
  final Set<String> orderIds = {};
}
