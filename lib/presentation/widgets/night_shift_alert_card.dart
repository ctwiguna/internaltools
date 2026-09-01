import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

/// Card dashboard owner: peringatan geofence shift malam yang belum
/// ditindaklanjuti + daftar pegawai shift malam yang sedang aktif berikut
/// lokasi terakhirnya. Data ditulis oleh app kedua
/// (flutter_laundry_nightshift_app), tabel dari
/// supabase/migrations/004_night_shift_tracking.sql.
///
/// Pola sama seperti WeeklyAttendanceRecap: StatefulWidget mandiri +
/// FutureBuilder + query Supabase langsung, tanpa Cubit/repository
/// terpisah (data ini hanya dipakai di satu tempat).
class NightShiftAlertCard extends StatefulWidget {
  const NightShiftAlertCard({super.key});

  @override
  State<NightShiftAlertCard> createState() => _NightShiftAlertCardState();
}

class _NightShiftAlertCardState extends State<NightShiftAlertCard> {
  late Future<_NightShiftData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<_NightShiftData> _load() async {
    final client = SupabaseService.instance.client;

    final alertRows = await client
        .from('geofence_alerts')
        .select('id, outlet_id, user_name, distance_m, latitude, longitude, occurred_at')
        .isFilter('acknowledged_at', null)
        .order('occurred_at', ascending: false)
        .limit(20);

    final activeShiftRows = await client
        .from('attendance')
        .select('id, outlet_id, user_name, check_in_at')
        .eq('shift_type', 'night')
        .isFilter('check_out_at', null)
        .order('check_in_at', ascending: false);

    final outletRows = await client.from('outlets').select('id, name');
    final outletNames = {
      for (final o in outletRows as List) o['id'] as String: (o['name'] as String?) ?? '-',
    };

    final activeIds = (activeShiftRows as List).map((r) => r['id'] as String).toList();
    final Map<String, Map<String, dynamic>> latestPingByAttendance = {};
    if (activeIds.isNotEmpty) {
      final pingRows = await client
          .from('shift_locations')
          .select('attendance_id, latitude, longitude, recorded_at')
          .inFilter('attendance_id', activeIds)
          .order('recorded_at', ascending: false);
      for (final row in pingRows as List) {
        final id = row['attendance_id'] as String;
        latestPingByAttendance.putIfAbsent(id, () => row as Map<String, dynamic>);
      }
    }

    final alerts = (alertRows as List)
        .map((row) => _AlertRow(
              id: row['id'] as String,
              outletName: outletNames[row['outlet_id'] as String?] ?? '-',
              userName: (row['user_name'] as String?) ?? '-',
              distanceM: (row['distance_m'] as num?)?.toDouble() ?? 0,
              latitude: (row['latitude'] as num).toDouble(),
              longitude: (row['longitude'] as num).toDouble(),
              occurredAt: DateTime.parse(row['occurred_at'] as String),
            ))
        .toList();

    final activeShifts = activeShiftRows.map((row) {
      final id = row['id'] as String;
      final ping = latestPingByAttendance[id];
      return _ActiveShiftRow(
        outletName: outletNames[row['outlet_id'] as String?] ?? '-',
        userName: (row['user_name'] as String?) ?? '-',
        checkInAt: DateTime.parse(row['check_in_at'] as String),
        lastPingAt:
            ping != null ? DateTime.parse(ping['recorded_at'] as String) : null,
        latitude: ping != null ? (ping['latitude'] as num).toDouble() : null,
        longitude: ping != null ? (ping['longitude'] as num).toDouble() : null,
      );
    }).toList();

    return _NightShiftData(alerts: alerts, activeShifts: activeShifts);
  }

  Future<void> _acknowledge(String alertId) async {
    final client = SupabaseService.instance.client;
    final myProfileId = client.auth.currentUser?.id;
    try {
      await client.from('geofence_alerts').update({
        'acknowledged_at': DateTime.now().toIso8601String(),
        'acknowledged_by': myProfileId,
      }).eq('id', alertId);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppThemeColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openMaps(double lat, double lng) async {
    final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgRadius,
          boxShadow: AppShadows.card,
        ),
        child: FutureBuilder<_NightShiftData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.nightlight_round, color: AppThemeColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Shift Malam', style: AppTypography.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _reload,
                      tooltip: 'Muat ulang',
                    ),
                  ],
                ),
                if (data == null)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else ...[
                  if (data.alerts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Peringatan keluar radius (${data.alerts.length})',
                      style: AppTypography.labelMedium.copyWith(color: AppThemeColors.error),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...data.alerts.map((a) => _AlertTile(
                          alert: a,
                          onOpenMaps: () => _openMaps(a.latitude, a.longitude),
                          onAcknowledge: () => _acknowledge(a.id),
                        )),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    'Sedang bertugas (${data.activeShifts.length})',
                    style: AppTypography.labelMedium.copyWith(color: AppThemeColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (data.activeShifts.isEmpty)
                    Text(
                      'Tidak ada shift malam yang sedang berjalan',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppThemeColors.textSecondary),
                    )
                  else
                    ...data.activeShifts.map((s) => _ActiveShiftTile(
                          shift: s,
                          onOpenMaps: s.latitude != null && s.longitude != null
                              ? () => _openMaps(s.latitude!, s.longitude!)
                              : null,
                        )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final _AlertRow alert;
  final VoidCallback onOpenMaps;
  final VoidCallback onAcknowledge;

  const _AlertTile({
    required this.alert,
    required this.onOpenMaps,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppThemeColors.error.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppThemeColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${alert.userName} • ${alert.outletName}',
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Keluar radius ${alert.distanceM.round()} m • '
            '${DateFormat('d MMM HH:mm').format(alert.occurredAt)}',
            style: AppTypography.bodySmall.copyWith(color: AppThemeColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: onOpenMaps,
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Buka di Maps'),
              ),
              const Spacer(),
              TextButton(
                onPressed: onAcknowledge,
                child: const Text('Tandai Ditindaklanjuti'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveShiftTile extends StatelessWidget {
  final _ActiveShiftRow shift;
  final VoidCallback? onOpenMaps;

  const _ActiveShiftTile({required this.shift, this.onOpenMaps});

  @override
  Widget build(BuildContext context) {
    final stale = shift.lastPingAt == null ||
        DateTime.now().difference(shift.lastPingAt!) > const Duration(minutes: 15);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: stale ? AppThemeColors.disabled : AppThemeColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shift.userName} • ${shift.outletName}',
                  style: AppTypography.bodyMedium,
                ),
                Text(
                  shift.lastPingAt != null
                      ? 'Update terakhir ${DateFormat.Hm().format(shift.lastPingAt!)}'
                          '${stale ? ' (mungkin app ditutup)' : ''}'
                      : 'Belum ada data lokasi',
                  style: AppTypography.bodySmall.copyWith(color: AppThemeColors.textSecondary),
                ),
              ],
            ),
          ),
          if (onOpenMaps != null)
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 18),
              onPressed: onOpenMaps,
              tooltip: 'Buka di Maps',
            ),
        ],
      ),
    );
  }
}

class _NightShiftData {
  final List<_AlertRow> alerts;
  final List<_ActiveShiftRow> activeShifts;

  const _NightShiftData({required this.alerts, required this.activeShifts});
}

class _AlertRow {
  final String id;
  final String outletName;
  final String userName;
  final double distanceM;
  final double latitude;
  final double longitude;
  final DateTime occurredAt;

  const _AlertRow({
    required this.id,
    required this.outletName,
    required this.userName,
    required this.distanceM,
    required this.latitude,
    required this.longitude,
    required this.occurredAt,
  });
}

class _ActiveShiftRow {
  final String outletName;
  final String userName;
  final DateTime checkInAt;
  final DateTime? lastPingAt;
  final double? latitude;
  final double? longitude;

  const _ActiveShiftRow({
    required this.outletName,
    required this.userName,
    required this.checkInAt,
    this.lastPingAt,
    this.latitude,
    this.longitude,
  });
}
