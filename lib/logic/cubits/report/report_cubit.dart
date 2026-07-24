import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/repositories/report_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_report_repository.dart';
import 'package:flutter_laundry_offline_app/core/services/export_service.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/report/report_state.dart';

class ReportCubit extends Cubit<ReportState> {
  final ReportRepository _reportRepository;
  final SupabaseReportRepository _onlineRepository;
  final ExportService _exportService;
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;

  ReportCubit({
    ReportRepository? reportRepository,
    SupabaseReportRepository? onlineRepository,
    ExportService? exportService,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
  })  : _reportRepository = reportRepository ?? ReportRepository(),
        _onlineRepository = onlineRepository ?? SupabaseReportRepository(),
        _exportService = exportService ?? ExportService(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance,
        super(const ReportInitial());

  bool get _isOnline => _connectivity.isOnline && _supabase.isAuthenticated;

  /// Load report data (mengikuti outlet aktif saat online)
  Future<void> loadReport(DateTime startDate, DateTime endDate) async {
    emit(const ReportLoading());

    try {
      if (_isOnline) {
        final data =
            await _onlineRepository.getReportData(startDate, endDate);
        final orders = await _onlineRepository.getOrdersByDateRange(
            startDate, endDate);

        emit(ReportLoaded(data: data, orders: orders));
        return;
      }

      final data = await _reportRepository.getReportData(startDate, endDate);
      final orders =
          await _reportRepository.getOrdersByDateRange(startDate, endDate);

      emit(ReportLoaded(data: data, orders: orders));
    } catch (e) {
      emit(ReportError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Export report to Excel
  Future<void> exportToExcel() async {
    final currentState = state;
    if (currentState is! ReportLoaded) return;

    emit(const ReportExporting());

    try {
      final filePath = await _exportService.exportOrdersToExcel(
        currentState.orders,
        currentState.data,
      );

      // Share the file
      await _exportService.shareFile(filePath);

      emit(ReportExported(
        filePath: filePath,
        message: 'Laporan berhasil di-export',
      ));

      // Restore previous state
      emit(currentState);
    } catch (e) {
      emit(ReportError(e.toString().replaceAll('Exception: ', '')));
      emit(currentState);
    }
  }
}
