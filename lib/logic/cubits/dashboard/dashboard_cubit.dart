import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/order.dart';
import 'package:flutter_laundry_offline_app/data/repositories/order_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/payment_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_order_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/dashboard/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;
  final SupabaseOrderRepository _onlineRepository;
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;

  DashboardCubit({
    OrderRepository? orderRepository,
    PaymentRepository? paymentRepository,
    SupabaseOrderRepository? onlineRepository,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
  })  : _orderRepository = orderRepository ?? OrderRepository(),
        _paymentRepository = paymentRepository ?? PaymentRepository(),
        _onlineRepository = onlineRepository ?? SupabaseOrderRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance,
        super(const DashboardInitial());

  bool get _isOnline => _connectivity.isOnline && _supabase.isAuthenticated;

  /// Jumlah order yang belum Selesai (pending/process/ready) dari total
  /// hitungan per status — bukan cuma order hari ini, supaya backlog yang
  /// menumpuk dari hari-hari sebelumnya tetap kelihatan.
  int _countUnfinished(Map<OrderStatus, int> statusCounts) {
    return statusCounts.entries
        .where((entry) => entry.key != OrderStatus.done)
        .fold<int>(0, (sum, entry) => sum + entry.value);
  }

  /// Load dashboard data (mengikuti outlet aktif)
  Future<void> loadDashboard() async {
    emit(const DashboardLoading());

    try {
      // Mode online: statistik langsung dari Supabase (per outlet aktif)
      if (_isOnline) {
        final results = await Future.wait([
          _onlineRepository.getTodayOrderCountByStatus(),
          _onlineRepository.getTodayRevenue(),
          _onlineRepository.getOrderCountByStatus(),
          _onlineRepository.getRecentOrders(limit: 5),
        ]);

        emit(DashboardLoaded(
          todayStatusCounts: results[0] as Map<OrderStatus, int>,
          todayRevenue: results[1] as int,
          unfinishedOrderCount:
              _countUnfinished(results[2] as Map<OrderStatus, int>),
          recentOrders: results[3] as List<Order>,
        ));
        return;
      }

      // Mode offline: statistik dari SQLite lokal
      final results = await Future.wait([
        _orderRepository.getTodayOrderCountByStatus(),
        _paymentRepository.getTodayRevenue(),
        _orderRepository.getOrderCountByStatus(),
        _orderRepository.getRecentOrders(limit: 5),
      ]);

      emit(DashboardLoaded(
        todayStatusCounts: results[0] as Map<OrderStatus, int>,
        todayRevenue: results[1] as int,
        unfinishedOrderCount:
            _countUnfinished(results[2] as Map<OrderStatus, int>),
        recentOrders: results[3] as List<Order>,
      ));
    } catch (e) {
      emit(DashboardError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
