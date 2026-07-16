import 'package:flutter/material.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';
import 'package:flutter_laundry_offline_app/core/theme/app_theme.dart';

/// Widget to display connectivity and sync status
class ConnectivityStatusWidget extends StatefulWidget {
  /// Show as a banner at the top of the screen
  final bool showAsBanner;

  /// Show detailed status info
  final bool showDetails;

  const ConnectivityStatusWidget({
    super.key,
    this.showAsBanner = false,
    this.showDetails = false,
  });

  @override
  State<ConnectivityStatusWidget> createState() =>
      _ConnectivityStatusWidgetState();
}

class _ConnectivityStatusWidgetState extends State<ConnectivityStatusWidget> {
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final SyncService _syncService = SyncService.instance;

  bool _isOnline = false;
  bool _isAuthenticated = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    _connectivity.onConnectivityChanged.listen((_) => _updateStatus());
    _syncService.statusStream.listen((status) {
      if (mounted) {
        setState(() => _syncStatus = status);
      }
    });
  }

  Future<void> _updateStatus() async {
    if (!mounted) return;
    final pending = await _syncService.getPendingCount();
    // Check Supabase auth FIRST, then connectivity
    final isAuth = _supabase.isAuthenticated && _supabase.hasValidSession;
    setState(() {
      _isAuthenticated = isAuth;
      // Only consider online if authenticated to Supabase AND has internet
      _isOnline = isAuth && _connectivity.isOnline;
      _pendingCount = pending;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsBanner) {
      return _buildBanner();
    }
    return _buildChip();
  }

  Widget _buildBanner() {
    if (_isOnline && _isAuthenticated) {
      // Only show banner when syncing or has pending items
      if (_syncStatus == SyncStatus.syncing) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.blue.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Menyinkronkan data...',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }
      if (_pendingCount > 0) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.orange.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sync_problem,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '$_pendingCount data menunggu sinkronisasi',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Offline banner
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isOnline ? Icons.cloud_off : Icons.signal_wifi_off,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Mode Offline (tidak login)' : 'Mode Offline',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip() {
    if (_isOnline && _isAuthenticated) {
      if (_syncStatus == SyncStatus.syncing) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Syncing',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done,
              size: 12,
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              'Online',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_pendingCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_pendingCount',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.cloud_off : Icons.signal_wifi_off,
            size: 12,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small indicator for app bar - Enhanced with badge style
class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final SyncService _syncService = SyncService.instance;

  bool _isOnline = false;
  bool _isAuthenticated = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingCount = 0;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _updateStatus();
    _connectivity.onConnectivityChanged.listen((_) => _updateStatus());
    _syncService.statusStream.listen((status) {
      if (mounted) {
        setState(() => _syncStatus = status);
        if (status == SyncStatus.syncing) {
          _animController.repeat(reverse: true);
        } else {
          _animController.stop();
          _animController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus() async {
    if (!mounted) return;
    final pending = await _syncService.getPendingCount();
    // Check Supabase auth FIRST, then connectivity
    final isAuth = _supabase.isAuthenticated && _supabase.hasValidSession;
    setState(() {
      _isAuthenticated = isAuth;
      // Only consider online if authenticated to Supabase AND has internet
      _isOnline = isAuth && _connectivity.isOnline;
      _pendingCount = pending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isFullyOnline = _isOnline && _isAuthenticated;
    final bool isSyncing = _syncStatus == SyncStatus.syncing;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isSyncing ? _scaleAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSyncing
                    ? Colors.blue.withValues(alpha: 0.3)
                    : isFullyOnline
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSyncing
                      ? Colors.blue.withValues(alpha: 0.5)
                      : isFullyOnline
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSyncing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.blue.shade200,
                        ),
                      ),
                    )
                  else
                    Icon(
                      isFullyOnline
                          ? Icons.cloud_done_rounded
                          : _isOnline
                              ? Icons.cloud_off_rounded
                              : Icons.wifi_off_rounded,
                      size: 14,
                      color: isFullyOnline
                          ? Colors.green.shade200
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    isSyncing
                        ? 'Sync'
                        : isFullyOnline
                            ? 'Online'
                            : 'Offline',
                    style: TextStyle(
                      color: isSyncing
                          ? Colors.blue.shade200
                          : isFullyOnline
                              ? Colors.green.shade200
                              : Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_pendingCount > 0 && isFullyOnline && !isSyncing) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet to show sync status details
class SyncStatusBottomSheet extends StatefulWidget {
  const SyncStatusBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const SyncStatusBottomSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  @override
  State<SyncStatusBottomSheet> createState() => _SyncStatusBottomSheetState();
}

class _SyncStatusBottomSheetState extends State<SyncStatusBottomSheet> {
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final SyncService _syncService = SyncService.instance;

  bool _isOnline = false;
  bool _isAuthenticated = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingCount = 0;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _updateStatus();
  }

  Future<void> _updateStatus() async {
    final pending = await _syncService.getPendingCount();
    setState(() {
      _isOnline = _connectivity.isOnline;
      _isAuthenticated = _supabase.isAuthenticated;
      _syncStatus = _syncService.status;
      _pendingCount = pending;
      _lastSyncTime = _syncService.lastSyncTime;
    });
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    await _syncService.syncAll();
    await _updateStatus();
    setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              const Text(
                'Status Sinkronisasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusRow(
            icon: _isOnline ? Icons.wifi : Icons.wifi_off,
            label: 'Koneksi Internet',
            value: _isOnline ? 'Tersambung' : 'Tidak tersambung',
            color: _isOnline ? Colors.green : Colors.grey,
          ),
          const Divider(),
          _buildStatusRow(
            icon: _isAuthenticated ? Icons.person : Icons.person_off,
            label: 'Status Login',
            value: _isAuthenticated ? 'Login (Online)' : 'Offline Mode',
            color: _isAuthenticated ? Colors.green : Colors.grey,
          ),
          const Divider(),
          _buildStatusRow(
            icon: _syncStatus == SyncStatus.syncing
                ? Icons.sync
                : Icons.cloud_sync,
            label: 'Status Sync',
            value: _getSyncStatusText(),
            color: _getSyncStatusColor(),
          ),
          if (_pendingCount > 0) ...[
            const Divider(),
            _buildStatusRow(
              icon: Icons.pending_actions,
              label: 'Menunggu Sync',
              value: '$_pendingCount item',
              color: Colors.orange,
            ),
          ],
          if (_lastSyncTime != null) ...[
            const Divider(),
            _buildStatusRow(
              icon: Icons.history,
              label: 'Sync Terakhir',
              value: _formatTime(_lastSyncTime!),
              color: Colors.blue,
            ),
          ],
          const SizedBox(height: 20),
          if (_isOnline && _isAuthenticated)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncNow,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (!_isOnline || !_isAuthenticated)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isOnline
                          ? 'Login untuk mengaktifkan sinkronisasi cloud'
                          : 'Hubungkan ke internet untuk sinkronisasi',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSyncStatusText() {
    switch (_syncStatus) {
      case SyncStatus.idle:
        return 'Siap';
      case SyncStatus.syncing:
        return 'Sedang sync...';
      case SyncStatus.success:
        return 'Berhasil';
      case SyncStatus.error:
        return 'Error: ${_syncService.lastError ?? "Unknown"}';
    }
  }

  Color _getSyncStatusColor() {
    switch (_syncStatus) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else {
      return '${diff.inDays} hari lalu';
    }
  }
}
