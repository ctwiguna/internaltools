import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/sync/sync_state.dart';

class SyncCubit extends Cubit<SyncState> {
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;
  final SyncService _syncService;

  StreamSubscription? _connectivitySub;
  StreamSubscription? _syncStatusSub;

  SyncCubit({
    ConnectivityService? connectivity,
    SupabaseService? supabase,
    SyncService? syncService,
  })  : _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance,
        _syncService = syncService ?? SyncService.instance,
        super(const SyncState());

  /// Initialize and start listening to status changes
  Future<void> initialize() async {
    await _updateState();

    // Listen to connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) {
      _updateState();
    });

    // Listen to sync status changes
    _syncStatusSub = _syncService.statusStream.listen((status) {
      _updateState();
    });
  }

  Future<void> _updateState() async {
    final pendingCount = await _syncService.getPendingCount();

    emit(SyncState(
      isOnline: _connectivity.isOnline,
      isAuthenticated: _supabase.isAuthenticated,
      syncStatus: _syncService.status,
      pendingCount: pendingCount,
      lastSyncTime: _syncService.lastSyncTime,
      lastError: _syncService.lastError,
    ));
  }

  /// Trigger manual sync
  Future<void> syncNow() async {
    if (!_connectivity.isOnline || !_supabase.isAuthenticated) {
      return;
    }

    emit(state.copyWith(isSyncing: true));

    try {
      await _syncService.syncAll();
      await _updateState();
    } catch (e) {
      emit(state.copyWith(
        lastError: e.toString(),
        isSyncing: false,
      ));
    }
  }

  /// Clear all pending sync items
  Future<void> clearPendingSync() async {
    await _syncService.clearPendingSync();
    await _updateState();
  }

  /// Get connection mode string
  String get connectionMode {
    if (_connectivity.isOnline && _supabase.isAuthenticated) {
      return 'Online';
    }
    return 'Offline';
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    _syncStatusSub?.cancel();
    return super.close();
  }
}
