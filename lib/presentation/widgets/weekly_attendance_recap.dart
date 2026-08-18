import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../logic/cubits/auth/auth_cubit.dart';
import '../../../logic/cubits/auth/auth_state.dart';

/// Rekap absensi mingguan untuk OWNER (ctwiguna):
/// nama karyawan — outlet — jumlah absen + total kg lipat & setrika
/// per minggu (Senin–Minggu), mencakup SEMUA outlet.
/// Bisa digeser ke minggu sebelumnya/berikutnya. Akun lain tidak melihat
/// section ini.
class WeeklyAttendanceRecap extends StatefulWidget {
  const WeeklyAttendanceRecap({super.key});

  @override
  State<WeeklyAttendanceRecap> createState() => _WeeklyAttendanceRecapState();
}

class _WeeklyAttendanceRecapState extends State<WeeklyAttendanceRecap> {
  // 0 = minggu ini, -1 = minggu lalu, -2 = 2 minggu lalu, dst.
  int _weekOffset = 0;
  late Future<_RecapData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(_weekOffset);
  }

  bool _isOwner(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      return state.user.username.split('@').first.toLowerCase() == 'ctwiguna';
    }
    return false;
  }

  void _goToWeek(int offset) {
    if (offset > 0) return; // tidak bisa lihat minggu depan
    setState(() {
      _weekOffset = offset;
      _future = _load(_weekOffset);
    });
  }

  Future<_RecapData> _load(int weekOffset) async {
    final client = SupabaseService.instance.client;

    // Awal minggu = Senin 00:00 (waktu lokal), digeser sesuai weekOffset
    final now = DateTime.now();
    final thisMonday =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final monday = thisMonday.add(Duration(days: 7 * weekOffset));
    final sunday = monday.add(const Duration(days: 6));
    final nextMonday = monday.add(const Duration(days: 7));

    // Absensi dalam rentang minggu terpilih (semua outlet)
    final attendanceRows = await client
        .from('attendance')
        .select('user_name, outlet_id, lipat_kg, setrika_kg')
        .gte('check_in_at', monday.toIso8601String())
        .lt('check_in_at', nextMonday.toIso8601String());

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgRadius,
          boxShadow: AppShadows.card,
        ),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -200) {
              // swipe kiri -> minggu berikutnya
              _goToWeek(_weekOffset + 1);
            } else if (velocity > 200) {
              // swipe kanan -> minggu sebelumnya
              _goToWeek(_weekOffset - 1);
            }
          },
          child: FutureBuilder<_RecapData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final periodLabel = data == null
                  ? ''
                  : '${DateFormat('d MMM').format(data.monday)} – '
                      '${DateFormat('d MMM yyyy').format(data.sunday)}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined,
                          color: AppThemeColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _weekOffset == 0
                            ? 'Rekap Absensi Minggu Ini'
                            : 'Rekap Absensi Mingguan',
                        style: AppTypography.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _goToWeek(_weekOffset - 1),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_left,
                              size: 20, color: AppThemeColors.primary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          periodLabel,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppThemeColors.textSecondary),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap:
                            _weekOffset < 0 ? () => _goToWeek(_weekOffset + 1) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: _weekOffset < 0
                                ? AppThemeColors.primary
                                : AppThemeColors.textSecondary
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
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
                      _weekOffset == 0
                          ? 'Belum ada absensi minggu ini'
                          : 'Tidak ada absensi pada minggu ini',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppThemeColors.textSecondary),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: data.rows.length,
                        itemBuilder: (context, index) {
                          final r = data.rows[index];
                          return Padding(
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
                                      style:
                                          AppTypography.bodyMedium.copyWith(
                                        color: AppThemeColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (r.lipatKg > 0 ||
                                        r.setrikaKg > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Lipat ${_fmtKg(r.lipatKg)} kg',
                                        style:
                                            AppTypography.bodySmall.copyWith(
                                          color: AppThemeColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        'Setrika ${_fmtKg(r.setrikaKg)} kg',
                                        style:
                                            AppTypography.bodySmall.copyWith(
                                          color: AppThemeColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
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
