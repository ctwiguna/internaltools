import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/utils/date_formatter.dart';
import 'package:flutter_laundry_offline_app/data/models/order.dart';
import 'package:flutter_laundry_offline_app/data/models/order_item.dart';
import 'package:flutter_laundry_offline_app/data/models/payment.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_customer_repository.dart';

/// Repository for order data from Supabase
class SupabaseOrderRepository {
  final SupabaseService _supabase;
  final SupabaseCustomerRepository _customerRepository;

  SupabaseOrderRepository({
    SupabaseService? supabase,
    SupabaseCustomerRepository? customerRepository,
  })  : _supabase = supabase ?? SupabaseService.instance,
        _customerRepository =
            customerRepository ?? SupabaseCustomerRepository();

  /// UUID outlet aktif (mengikuti OutletService) — untuk memfilter
  /// data per outlet, terutama saat owner berpindah-pindah outlet.
  String? get _outletUuid => OutletService.instance.currentOutletUuid;

  /// Get all orders with optional filter and pagination
  Future<List<Order>> getAllOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _supabase.client.from('orders').select();

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);

    if (status != null) {
      query = query.eq('status', status.value);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((map) => Order.fromSupabase(map)).toList();
  }

  /// Get order by remote ID with items and payments
  Future<Order?> getOrderById(String id) async {
    final orderData = await _supabase.client
        .from('orders')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (orderData == null) return null;

    final order = Order.fromSupabase(orderData);

    // Get items
    final itemsData = await _supabase.client
        .from('order_items')
        .select()
        .eq('order_id', id);

    final items =
        (itemsData as List).map((map) => OrderItem.fromSupabase(map)).toList();

    // Get payments
    final paymentsData = await _supabase.client
        .from('payments')
        .select()
        .eq('order_id', id)
        .order('payment_date', ascending: false);

    final payments =
        (paymentsData as List).map((map) => Payment.fromSupabase(map)).toList();

    return order.copyWith(items: items, payments: payments);
  }

  /// Generate nomor invoice secara atomik di server (anti tabrakan
  /// antar device) via fungsi SQL next_invoice_no.
  Future<String> generateInvoiceNo() async {
    final uuid = _outletUuid;
    if (uuid == null) {
      throw Exception('Outlet aktif belum dipilih');
    }

    final prefix =
        OutletService.instance.currentOutlet?.invoicePrefix ?? 'INV';
    final dateStr = DateFormatter.formatForInvoice(DateTime.now());

    final result = await _supabase.client.rpc('next_invoice_no', params: {
      'p_outlet_id': uuid,
      'p_prefix': prefix,
      'p_date_str': dateStr,
    });

    return result as String;
  }

  /// Create new order with items
  Future<Order> createOrder({
    required Order order,
    required List<OrderItem> items,
    Payment? initialPayment,
  }) async {
    // Auto-save customer if phone is provided
    String? customerId = order.customerRemoteId;
    if (order.customerPhone != null &&
        order.customerPhone!.isNotEmpty &&
        order.outletId != null) {
      try {
        final customer = await _customerRepository.getOrCreateByPhone(
          name: order.customerName,
          phone: order.customerPhone!,
          outletId: order.outletId!,
        );
        customerId = customer.remoteId;
      } catch (_) {
        // Ignore customer creation errors
      }
    }

    // Insert order
    final orderMap = order.toSupabaseMap();
    orderMap['customer_id'] = customerId;
    // Nomor invoice selalu dibuat atomik di server
    orderMap['invoice_no'] = await generateInvoiceNo();

    final orderData = await _supabase.client
        .from('orders')
        .insert(orderMap)
        .select()
        .single();

    final createdOrder = Order.fromSupabase(orderData);

    // Insert items
    for (final item in items) {
      final itemMap = item.toSupabaseMap();
      itemMap['order_id'] = createdOrder.remoteId;
      await _supabase.client.from('order_items').insert(itemMap);
    }

    // Insert initial payment if provided
    if (initialPayment != null && initialPayment.amount > 0) {
      final paymentMap = initialPayment.toSupabaseMap();
      paymentMap['order_id'] = createdOrder.remoteId;
      await _supabase.client.from('payments').insert(paymentMap);
    }

    // Update customer stats
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

    return createdOrder.copyWith(customerRemoteId: customerId);
  }

  /// Update order status
  Future<void> updateOrderStatus(String id, OrderStatus newStatus) async {
    await _supabase.client.from('orders').update({
      'status': newStatus.value,
    }).eq('id', id);
  }

  /// Delete order
  Future<void> deleteOrder(String id) async {
    // Items and payments will be cascade deleted via RLS
    await _supabase.client.from('orders').delete().eq('id', id);
  }

  /// Search orders
  Future<List<Order>> searchOrders(String query) async {
    var q = _supabase.client
        .from('orders')
        .select()
        .or('customer_name.ilike.%$query%,customer_phone.ilike.%$query%,invoice_no.ilike.%$query%');

    final uuid = _outletUuid;
    if (uuid != null) q = q.eq('outlet_id', uuid);

    final data = await q.order('created_at', ascending: false);

    return (data as List).map((map) => Order.fromSupabase(map)).toList();
  }

  /// Get orders by date range
  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end) async {
    final startStr =
        DateTime(start.year, start.month, start.day).toIso8601String();
    final endStr = DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
        .toIso8601String();

    var query = _supabase.client
        .from('orders')
        .select()
        .gte('order_date', startStr)
        .lte('order_date', endStr);

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);

    final data = await query.order('created_at', ascending: false);

    return (data as List).map((map) => Order.fromSupabase(map)).toList();
  }

  /// Get orders by status count
  Future<Map<OrderStatus, int>> getOrderCountByStatus() async {
    final counts = <OrderStatus, int>{};
    final uuid = _outletUuid;

    for (final status in OrderStatus.values) {
      var query = _supabase.client
          .from('orders')
          .select('id')
          .eq('status', status.value);

      if (uuid != null) query = query.eq('outlet_id', uuid);

      final data = await query;
      counts[status] = (data as List).length;
    }

    return counts;
  }

  /// Get today's order count by status
  Future<Map<OrderStatus, int>> getTodayOrderCountByStatus() async {
    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999)
        .toIso8601String();

    final counts = <OrderStatus, int>{};
    final uuid = _outletUuid;

    for (final status in OrderStatus.values) {
      var query = _supabase.client
          .from('orders')
          .select('id')
          .eq('status', status.value)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);

      if (uuid != null) query = query.eq('outlet_id', uuid);

      final data = await query;
      counts[status] = (data as List).length;
    }

    return counts;
  }

  /// Get today's revenue (total pembayaran yang diterima hari ini)
  Future<int> getTodayRevenue() async {
    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999)
        .toIso8601String();

    var q = _supabase.client
        .from('payments')
        .select('amount, orders!inner(outlet_id)')
        .gte('payment_date', startOfDay)
        .lte('payment_date', endOfDay);

    final uuid = _outletUuid;
    if (uuid != null) q = q.eq('orders.outlet_id', uuid);

    final data = await q;
    return (data as List)
        .fold<int>(0, (sum, row) => sum + (row['amount'] as num).toInt());
  }

  /// Get this month's order count
  Future<int> getThisMonthOrderCount() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    var query = _supabase.client
        .from('orders')
        .select('id')
        .gte('order_date', startOfMonth);

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);

    final data = await query;
    return (data as List).length;
  }

  /// Get recent orders
  Future<List<Order>> getRecentOrders({int limit = 5}) async {
    var query = _supabase.client.from('orders').select();

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);

    final data =
        await query.order('created_at', ascending: false).limit(limit);

    return (data as List).map((map) => Order.fromSupabase(map)).toList();
  }

  /// Update paid amount after payment
  Future<void> updatePaidAmount(String orderId, int newPaidAmount) async {
    await _supabase.client.from('orders').update({
      'paid': newPaidAmount,
    }).eq('id', orderId);
  }

  /// Add payment to order
  Future<Payment> addPayment(Payment payment) async {
    final data = await _supabase.client
        .from('payments')
        .insert(payment.toSupabaseMap())
        .select()
        .single();

    final createdPayment = Payment.fromSupabase(data);

    // Update order paid amount.
    // getOrderById sudah memuat payment yang baru diinsert,
    // jadi cukup jumlahkan seluruh payments (jangan + payment.amount lagi).
    final order = await getOrderById(payment.orderRemoteId!);
    if (order != null) {
      final totalPaid =
          order.payments?.fold<int>(0, (sum, p) => sum + p.amount) ?? 0;
      await updatePaidAmount(payment.orderRemoteId!, totalPaid);
    }

    return createdPayment;
  }
}
