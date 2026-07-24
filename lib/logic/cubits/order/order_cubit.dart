import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/utils/invoice_generator.dart';
import 'package:flutter_laundry_offline_app/data/models/order.dart';
import 'package:flutter_laundry_offline_app/data/models/order_item.dart';
import 'package:flutter_laundry_offline_app/data/models/payment.dart';
import 'package:flutter_laundry_offline_app/data/repositories/customer_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/hybrid_order_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/payment_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/order/order_state.dart';

class OrderCubit extends Cubit<OrderState> {
  final HybridOrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;
  final CustomerRepository _customerRepository;
  List<Order> _orders = [];
  OrderStatus? _currentFilter;
  static const int _pageSize = 20;
  bool _hasMore = true;

  OrderCubit({
    HybridOrderRepository? orderRepository,
    PaymentRepository? paymentRepository,
    CustomerRepository? customerRepository,
  })  : _orderRepository = orderRepository ?? HybridOrderRepository(),
        _paymentRepository = paymentRepository ?? PaymentRepository(),
        _customerRepository = customerRepository ?? CustomerRepository(),
        super(const OrderInitial());

  List<Order> get orders => _orders;
  OrderStatus? get currentFilter => _currentFilter;
  bool get hasMore => _hasMore;

  /// Load all orders with optional filter (first page)
  Future<void> loadOrders({OrderStatus? status}) async {
    emit(const OrderLoading());
    _currentFilter = status;
    _orders = [];
    _hasMore = true;

    try {
      final newOrders = await _orderRepository.getAllOrders(
        status: status,
        limit: _pageSize,
        offset: 0,
      );
      _orders = newOrders;
      _hasMore = newOrders.length >= _pageSize;
      emit(OrderLoaded(_orders, filterStatus: status, hasMore: _hasMore));
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Load more orders (pagination)
  Future<void> loadMoreOrders() async {
    if (!_hasMore) return;

    final currentState = state;
    if (currentState is! OrderLoaded || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final newOrders = await _orderRepository.getAllOrders(
        status: _currentFilter,
        limit: _pageSize,
        offset: _orders.length,
      );

      _orders = [..._orders, ...newOrders];
      _hasMore = newOrders.length >= _pageSize;

      emit(OrderLoaded(
        _orders,
        filterStatus: _currentFilter,
        hasMore: _hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  /// Load order detail with items and payments
  /// (id bisa int lokal atau String UUID remote)
  Future<void> loadOrderDetail(dynamic id) async {
    emit(const OrderLoading());

    try {
      final order = await _orderRepository.getOrderById(id);
      if (order != null) {
        emit(OrderDetailLoaded(order));
      } else {
        emit(const OrderError('Order tidak ditemukan'));
      }
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Create new order
  Future<void> createOrder({
    required String customerName,
    String? customerPhone,
    int? customerId,
    String? customerRemoteId,
    required List<OrderItem> items,
    required DateTime dueDate,
    String? notes,
    int? createdBy,
    int initialPayment = 0,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  }) async {
    emit(const OrderLoading());

    try {
      // Validate
      if (customerName.trim().isEmpty) {
        emit(const OrderError('Nama customer tidak boleh kosong'));
        return;
      }
      if (items.isEmpty) {
        emit(const OrderError('Minimal 1 item harus dipilih'));
        return;
      }

      final isOnline = _orderRepository.isOnline;

      // Mode offline: simpan customer ke SQLite lokal.
      // Mode online: customer otomatis dicocokkan/dibuat di server
      // berdasarkan nomor HP (lihat SupabaseOrderRepository.createOrder).
      int? finalCustomerId = customerId;
      if (!isOnline && finalCustomerId == null) {
        try {
          final customer = customerPhone != null && customerPhone.trim().isNotEmpty
              ? await _customerRepository.getOrCreateByPhone(
                  name: customerName,
                  phone: customerPhone,
                )
              : await _customerRepository.getOrCreateByName(
                  name: customerName,
                );
          finalCustomerId = customer.id;
        } catch (e) {
          // If customer creation fails, continue without customerId
          // This allows order creation even if customer save fails
        }
      }

      // Calculate totals
      int totalItems = items.length;
      double totalWeight = 0;
      int totalPrice = 0;

      for (final item in items) {
        totalWeight += item.quantity;
        totalPrice += item.subtotal;
      }

      // Generate invoice.
      // Online: dibuat atomik di server (placeholder ditimpa).
      // Offline: generator lokal.
      final invoiceNo =
          isOnline ? 'PENDING' : await InvoiceGenerator.generate();

      // Hitung kembalian (jika bayar lebih dari total)
      final change = initialPayment > totalPrice ? initialPayment - totalPrice : 0;
      // Yang dicatat sebagai "paid" di order adalah maksimal = totalPrice
      final paidAmount = initialPayment > totalPrice ? totalPrice : initialPayment;

      // Create order
      final order = Order(
        invoiceNo: invoiceNo,
        customerId: finalCustomerId,
        customerRemoteId: customerRemoteId,
        customerName: customerName.trim(),
        customerPhone: customerPhone?.trim(),
        orderDate: DateTime.now(),
        dueDate: dueDate,
        status: OrderStatus.pending,
        totalItems: totalItems,
        totalWeight: totalWeight,
        totalPrice: totalPrice,
        paid: paidAmount,
        notes: notes?.trim(),
        createdBy: createdBy,
      );

      // Prepare initial payment if any
      Payment? payment;
      if (initialPayment > 0) {
        payment = Payment(
          orderId: 0, // Will be set after order creation
          amount: initialPayment, // Simpan jumlah bayar apa adanya
          change: change, // Simpan kembalian
          paymentDate: DateTime.now(),
          paymentMethod: paymentMethod,
          receivedBy: createdBy,
        );
      }

      // Save to database
      final createdOrder = await _orderRepository.createOrder(
        order: order,
        items: items.map((item) => item.copyWith(orderId: 0)).toList(),
        initialPayment: payment,
      );

      emit(OrderCreated(createdOrder));

      // Reload orders
      await loadOrders(status: _currentFilter);
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Update order status (orderId bisa int lokal atau String UUID remote)
  Future<void> updateStatus(dynamic orderId, OrderStatus newStatus) async {
    emit(const OrderLoading());

    try {
      await _orderRepository.updateOrderStatus(orderId, newStatus);
      emit(OrderOperationSuccess('Status berhasil diubah ke ${newStatus.displayName}'));

      // Reload orders
      await loadOrders(status: _currentFilter);
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Add payment to order (orderId bisa int lokal atau String UUID remote)
  /// Menyimpan pembayaran apa adanya beserta kembalian
  Future<void> addPayment({
    required dynamic orderId,
    required int amount,
    required PaymentMethod method,
    String? notes,
    int? receivedBy,
  }) async {
    emit(const OrderLoading());

    try {
      // Get order to check remaining payment
      final order = await _orderRepository.getOrderById(orderId);
      if (order == null) {
        emit(const OrderError('Order tidak ditemukan'));
        return;
      }

      final remaining = order.remainingPayment;
      if (remaining <= 0) {
        emit(const OrderError('Order sudah lunas'));
        return;
      }

      // Hitung kembalian jika bayar lebih dari sisa
      final change = amount > remaining ? amount - remaining : 0;

      if (order.isRemote) {
        // Mode online: payment langsung ke Supabase
        final payment = Payment(
          orderRemoteId: order.remoteId,
          amount: amount, // Simpan apa adanya
          change: change, // Simpan kembalian
          paymentDate: DateTime.now(),
          paymentMethod: method,
          notes: notes,
        );

        final created = await _orderRepository.addPayment(payment);
        if (created == null) {
          emit(const OrderError('Gagal menyimpan pembayaran ke server'));
          return;
        }
      } else {
        // Mode offline: payment ke SQLite lokal
        final payment = Payment(
          orderId: orderId as int,
          amount: amount, // Simpan apa adanya
          change: change, // Simpan kembalian
          paymentDate: DateTime.now(),
          paymentMethod: method,
          notes: notes,
          receivedBy: receivedBy,
        );

        await _paymentRepository.addPayment(payment);
      }

      emit(const OrderOperationSuccess('Pembayaran berhasil ditambahkan'));

      // Reload order detail
      await loadOrderDetail(orderId);
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Delete order (orderId bisa int lokal atau String UUID remote)
  Future<void> deleteOrder(dynamic orderId) async {
    emit(const OrderLoading());

    try {
      await _orderRepository.deleteOrder(orderId);
      emit(const OrderOperationSuccess('Order berhasil dihapus'));

      // Reload orders
      await loadOrders(status: _currentFilter);
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Search orders
  Future<void> searchOrders(String query) async {
    emit(const OrderLoading());

    try {
      if (query.trim().isEmpty) {
        await loadOrders(status: _currentFilter);
        return;
      }

      _orders = await _orderRepository.searchOrders(query);
      emit(OrderLoaded(_orders));
    } catch (e) {
      emit(OrderError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
