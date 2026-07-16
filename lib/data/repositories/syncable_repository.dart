import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';

/// Base class for repositories that support Supabase sync
/// This provides a consistent pattern for offline-first data access with sync capability
abstract class SyncableRepository<T> {
  final ConnectivityService connectivity;
  final SupabaseService supabase;
  final SyncService syncService;

  SyncableRepository({
    ConnectivityService? connectivity,
    SupabaseService? supabase,
    SyncService? syncService,
  })  : connectivity = connectivity ?? ConnectivityService.instance,
        supabase = supabase ?? SupabaseService.instance,
        syncService = syncService ?? SyncService.instance;

  /// Check if we should use online mode
  bool get shouldUseOnline =>
      connectivity.isOnline && supabase.isAuthenticated;

  /// Table name in both local SQLite and Supabase
  String get tableName;

  /// Convert model to Supabase-compatible map
  Map<String, dynamic> toSupabaseMap(T model);

  /// Create model from Supabase response
  T fromSupabase(Map<String, dynamic> map);

  /// Queue item for sync when offline
  Future<void> queueForSync({
    required int localId,
    required SyncAction action,
    required Map<String, dynamic> data,
  }) async {
    await syncService.queueForSync(
      table: tableName,
      localId: localId,
      action: action,
      data: data,
    );
  }
}

/// Mixin for repositories that need outlet-scoped data
mixin OutletScopedRepository {
  String? _currentOutletId;

  /// Set the current outlet ID for filtering data
  void setOutletId(String? outletId) {
    _currentOutletId = outletId;
  }

  /// Get the current outlet ID
  String? get currentOutletId => _currentOutletId;
}
