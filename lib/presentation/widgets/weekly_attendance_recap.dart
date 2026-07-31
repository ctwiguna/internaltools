import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../logic/cubits/auth/auth_cubit.dart';
import '../../../logic/cubits/auth/auth_state.dart';

/// Rekap absensi mingguan untuk OWNER (ctwiguna):
/// nama karyawan — outlet — jumlah absen + total kg lipat & setrika
/// minggu ini (Senin–Minggu), mencakup SEMUA outlet.
/// Akun lain tidak melihat section ini.
class WeeklyAttendanceRecap extends StatelessWidget {
  const WeeklyAttendanceRecap({super.key});

  bool _isOwner(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      return state.user.username.split('@').first.toLowerCase() == 'ctwiguna';
    }
    return false;
  }

  Future<_RecapData> _load() async {
    final client = SupabaseService.instance.client;

    // Awal minggu = Senin 00:00 (waktu lokal)
    final now = DateTime.now();
    final monday =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    // Absensi sejak Senin (semua outlet)
    final attendanceRows = await client
        .from('attendance')
        .select('user_name, outlet_id, lipat_kg, setrika_kg')
        .gte('check_in_at', monday.toIso8601String());

    // Nama outlet
    final outletRows = await client.from('outlets').select('id, name');
    final outletNames = {
      for (final o in outletRows as List)
        o['id'] as String: (o['name'] as String?) ?? '-',
    };

    // Kelompokkan: karyawan + outlet -> jumlah absen + total kg
    final Map<String, _RecapRow> grouped = {};
    for (final row in attendanceRows as List) {
      final userName = (row['user_name'] as String?) ?? '-';
      final outletId = (row['outlet_id'] as String?) ?? '';
      final key = '$userName|$outletId';
      final rec = grouped.putIfAbsent(
        key,
        () => _RecapRow(
          userName: userName,
          outletName: outletNames[outletId] ?? '-',
          count: 0,
          lipatKg: 0,
          setrikaKg: 0,
        ),
      );
      rec.count += 1;
      rec.lipatKg += (row['lipat_kg'] as num?)?.toDouble() ?? 0;
      rec.setrikaKg += (row['setrika_kg'] as num?)?.toDouble() ?? 0;
    }

    final rows = grouped.values.toList()
      ..sort((a, b) {
        final byOutlet = a.outletName.compareTo(b.outletName);
        return byOutlet != 0 ? byOutlet : a.userName.compareTo(b.userName);
      });

    return _RecapData(monday: monday, sunday: sunday, rows: rows);
  }

  String _fmtKg(double kg) =>
      kg.toStringAsFixed(kg.truncateToDouble() == kg ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    if (!_isOwner(context)) return const SizedBox.shrink();

    return FutureBuilder<_RecapData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final periodLabel = data == null
            ? ''
            : 'Periode: ${DateFormat('d MMM').format(data.monday)} – '
                '${DateFormat('d MMM yyyy').format(data.sunday)}';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.lgRadius,
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined,
                        color: AppThemeColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Rekap Absensi Minggu Ini',
                      style: AppTypography.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  periodLabel,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppThemeColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                if (data == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (data.rows.isEmpty)
                  Text(
                    'Belum ada absensi minggu ini',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppThemeColors.textSecondary),
                  )
                else
                  ...data.rows.map(
                    (r) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              r.userName,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              r.outletName,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppThemeColors.textSecondary,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${r.count}x absen',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppThemeColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (r.lipatKg > 0 || r.setrikaKg > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Lipat ${_fmtKg(r.lipatKg)} kg',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppThemeColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Setrika ${_fmtKg(r.setrikaKg)} kg',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppThemeColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecapData {
  final DateTime monday;
  final DateTime sunday;
  final List<_RecapRow> rows;

  const _RecapData({
    required this.monday,
    required this.sunday,
    required this.rows,
  });
}

class _RecapRow {
  final String userName;
  final String outletName;
  int count;
  double lipatKg;
  double setrikaKg;

  _RecapRow({
    required this.userName,
    required this.outletName,
    required this.count,
    required this.lipatKg,
    required this.setrikaKg,
  });
}
