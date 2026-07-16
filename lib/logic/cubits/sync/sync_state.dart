import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';

class SyncState extends Equatable {
  final bool isOnline;
  final bool isAuthenticated;
  final SyncStatus syncStatus;
  final int pendingCount;
  final DateTime? lastSyncTime;
  final String? lastError;
  final bool isSyncing;

  const SyncState({
    this.isOnline = false,
    this.isAuthenticated = false,
    this.syncStatus = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastSyncTime,
    this.lastError,
    this.isSyncing = false,
  });

  /// Check if cloud features are available
  bool get isCloudAvailable => isOnline && isAuthenticated;

  /// Check if there are items pending sync
  bool get hasPendingSync => pendingCount > 0;

  /// Get user-friendly status text
  String get statusText {
    if (!isOnline) return 'Offline';
    if (!isAuthenticated) return 'Offline Mode';
    if (isSyncing) return 'Syncing...';
    if (syncStatus == SyncStatus.error) return 'Sync Error';
    if (hasPendingSync) return '$pendingCount pending';
    return 'Online';
  }

  SyncState copyWith({
    bool? isOnline,
    bool? isAuthenticated,
    SyncStatus? syncStatus,
    int? pendingCount,
    DateTime? lastSyncTime,
    String? lastError,
    bool? isSyncing,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: lastError ?? this.lastError,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => [
        isOnline,
        isAuthenticated,
        syncStatus,
        pendingCount,
        lastSyncTime,
        lastError,
        isSyncing,
      ];
}
