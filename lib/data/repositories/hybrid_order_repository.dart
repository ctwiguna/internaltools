import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/order.dart';
import 'package:flutter_laundry_offline_app/data/models/order_item.dart';
import 'package:flutter_laundry_offline_app/data/models/payment.dart';
import 'package:flutter_laundry_offline_app/data/repositories/order_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_order_repository.dart';

/// Hybrid repository that automatically switches between offline and online data sources
class HybridOrderRepository {
  final OrderRepository _offlineRepo;
  final SupabaseOrderRepository _onlineRepo;
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;

  /// Manual override outlet ID untuk operasi online (opsional).
  /// Default: otomatis mengikuti outlet aktif di OutletService.
  String? _manualOutletId;

  /// Manual override user remote ID (opsional).
  /// Default: user yang sedang login di Supabase.
  String? _userRemoteId;

  HybridOrderRepository({
    OrderRepository? offlineRepo,
    SupabaseOrderRepository? onlineRepo,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
  })  : _offlineRepo = offlineRepo ?? OrderRepository(),
        _onlineRepo = onlineRepo ?? SupabaseOrderRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance;

  /// Set outlet ID manual (opsional — biasanya tidak perlu karena
  /// otomatis mengikuti outlet aktif di OutletService)
  void setOutletId(String? outletId) {
    _manualOutletId = outletId;
  }

  /// Set the user remote ID for online operations
  void setUserRemoteId(String? userRemoteId) {
    _userRemoteId = userRemoteId;
  }

  /// Outlet UUID untuk operasi online — mengikuti outlet aktif
  String? get _outletId =>
      _manualOutletId ?? OutletService.instance.currentOutletUuid;

  /// User UUID untuk operasi online — mengikuti user yang login
  String? get _effectiveUserRemoteId =>
      _userRemoteId ?? _supabase.client.auth.currentUser?.id;

  /// Check if should use online mode
  bool get _shouldUseOnline =>
      _connectivity.isOnline && _supabase.isAuthenticated && _outletId != null;

  /// Apakah repository sedang beroperasi online (dipakai cubit)
  bool get isOnline => _shouldUseOnline;

  /// Get all orders with optional filter and pagination
  Future<List<Order>> getAllOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getAllOrders(
          status: status,
          limit: limit,
          offset: offset,
        );
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getAllOrders(
      status: status,
      limit: limit,
      offset: offset,
    );
  }

  /// Get order by ID (supports both local int ID and remote UUID)
  Future<Order?> getOrderById(dynamic id) async {
    if (id is String && _shouldUseOnline) {
      try {
        return await _onlineRepo.getOrderById(id);
      } catch (_) {
        // Fallback to offline
      }
    }
    if (id is int) {
      return await _offlineRepo.getOrderById(id);
    }
    return null;
  }

  /// Create new order with items
  Future<Order> createOrder({
    required Order order,
    required List<OrderItem> items,
    Payment? initialPayment,
  }) async {
    if (_shouldUseOnline && _outletId != null) {
      try {
        return await _onlineRepo.createOrder(
          order: order.copyWith(
            outletId: _outletId,
            createdByRemoteId: _effectiveUserRemoteId,
          ),
          items: items,
          initialPayment: initialPayment?.copyWith(
            receivedByRemoteId: _effectiveUserRemoteId,
          ),
        );
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.createOrder(
      order: order,
      items: items,
      initialPayment: initialPayment,
    );
  }

  /// Update order status
  Future<void> updateOrderStatus(dynamic id, OrderStatus newStatus) async {
    if (id is String && _shouldUseOnline) {
      try {
        await _onlineRepo.updateOrderStatus(id, newStatus);
        return;
      } catch (_) {
        // Cannot fallback update to offline for remote order
        rethrow;
      }
    }
    if (id is int) {
      await _offlineRepo.updateOrderStatus(id, newStatus);
    }
  }

  /// Delete order
  Future<void> deleteOrder(dynamic id) async {
    if (id is String && _shouldUseOnline) {
      try {
        await _onlineRepo.deleteOrder(id);
        return;
      } catch (_) {
        // Cannot fallback delete to offline for remote order
        rethrow;
      }
    }
    if (id is int) {
      await _offlineRepo.deleteOrder(id);
    }
  }

  /// Search orders
  Future<List<Order>> searchOrders(String query) async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.searchOrders(query);
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.searchOrders(query);
  }

  /// Get orders by date range
  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end) async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getOrdersByDateRange(start, end);
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getOrdersByDateRange(start, end);
  }

  /// Get order count by status
  Future<Map<OrderStatus, int>> getOrderCountByStatus() async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getOrderCountByStatus();
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getOrderCountByStatus();
  }

  /// Get today's order count by status
  Future<Map<OrderStatus, int>> getTodayOrderCountByStatus() async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getTodayOrderCountByStatus();
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getTodayOrderCountByStatus();
  }

  /// Get recent orders
  Future<List<Order>> getRecentOrders({int limit = 5}) async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getRecentOrders(limit: limit);
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getRecentOrders(limit: limit);
  }

  /// Update paid amount after payment
  Future<void> updatePaidAmount(dynamic orderId, int newPaidAmount) async {
    if (orderId is String && _shouldUseOnline) {
      try {
        await _onlineRepo.updatePaidAmount(orderId, newPaidAmount);
        return;
      } catch (_) {
        // Cannot fallback update to offline for remote order
        rethrow;
      }
    }
    if (orderId is int) {
      await _offlineRepo.updatePaidAmount(orderId, newPaidAmount);
    }
  }

  /// Add payment to order (online only)
  Future<Payment?> addPayment(Payment payment) async {
    if (_shouldUseOnline && payment.orderRemoteId != null) {
      try {
        return await _onlineRepo.addPayment(
          payment.copyWith(receivedByRemoteId: _effectiveUserRemoteId),
        );
      } catch (_) {
        // Ignore errors
      }
    }
    return null;
  }
}
