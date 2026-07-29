import 'package:flutter_laundry_offline_app/presentation/widgets/weekly_attendance_recap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/constants/app_constants.dart';
import 'package:flutter_laundry_offline_app/core/theme/app_theme.dart';
import 'package:flutter_laundry_offline_app/data/models/attendance.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/attendance/attendance_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/attendance/attendance_state.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_state.dart';
import 'package:flutter_laundry_offline_app/presentation/screens/attendance/attendance_checkin_screen.dart';
import 'package:intl/intl.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

void _loadData() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      final user = authState.user;
      // Owner (ctwiguna) = mode monitoring: lihat semua absensi
      // di outlet aktif. Akun lain hanya melihat absensinya sendiri.
      final isOwnerMonitor =
          user.username.split('@').first.toLowerCase() == 'ctwiguna';
      context.read<AttendanceCubit>().loadAttendances(
            userId: isOwnerMonitor ? null : user.id,
            userRemoteId: isOwnerMonitor ? null : user.remoteId,
          );
    }
  }

  Future<void> _navigateToCheckIn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AttendanceCubit>(),
          child: const AttendanceCheckInScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        title: const Text('Absensi Karyawan'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: BlocBuilder<AttendanceCubit, AttendanceState>(
        builder: (context, state) {
          if (state is AttendanceLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AttendanceError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppThemeColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(state.message, style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          if (state is AttendanceLoaded) {
            final attendances = state.attendances;
            final hasCheckedInToday = state.hasCheckedInToday;

            return Column(
              children: [
                // Today's status card
                Container(
                  margin: const EdgeInsets.all(AppSpacing.lg),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: hasCheckedInToday ? AppThemeColors.success : Colors.white,
                    borderRadius: AppRadius.lgRadius,
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: hasCheckedInToday
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppThemeColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasCheckedInToday ? Icons.check_circle : Icons.pending_actions,
                          color: hasCheckedInToday ? Colors.white : AppThemeColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasCheckedInToday
                                  ? 'Sudah Absen Hari Ini'
                                  : 'Belum Absen Hari Ini',
                              style: AppTypography.titleLarge.copyWith(
                                color: hasCheckedInToday ? Colors.white : AppThemeColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              hasCheckedInToday
                                  ? 'Anda sudah melakukan absensi dengan checklist lengkap.'
                                  : 'Silakan lakukan absensi dan checklist kebersihan.',
                              style: AppTypography.bodySmall.copyWith(
                                color: hasCheckedInToday
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : AppThemeColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Check-in button
                if (!hasCheckedInToday)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToCheckIn,
                        icon: const Icon(Icons.login, color: Colors.white),
                        label: Text('Absen Masuk Sekarang', style: AppTypography.button),
                      ),
                    ),
                  ),

                const SizedBox(height: AppSpacing.lg),
            // Rekap mingguan (owner saja)
            const WeeklyAttendanceRecap(),
            const SizedBox(height: AppSpacing.lg),
                // List header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      Text(
                        'Riwayat Absensi',
                        style: AppTypography.headlineSmall,
                      ),
                      const Spacer(),
                      Text(
                        '${attendances.length} data',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // List
                Expanded(
                  child: attendances.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 64,
                                color: AppThemeColors.textHint,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Belum ada data absensi',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppThemeColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          itemCount: attendances.length,
                          itemBuilder: (context, index) {
                            final item = attendances[index];
                            return _AttendanceCard(attendance: item);
                          },
                        ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final Attendance attendance;

  const _AttendanceCard({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(AppConstants.dateFormat).format(attendance.checkInAt);
    final timeStr = DateFormat(AppConstants.timeFormat).format(attendance.checkInAt);
    final checklistCount = attendance.checklist.length;
    final checkedCount = attendance.checklist.where((c) {
      final checked = c['checked'];
      return checked == true || checked == 'true';
    }).length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppThemeColors.primarySurface,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: const Icon(
                  Icons.person_pin,
                  color: AppThemeColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attendance.userName,
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$dateStr • $timeStr',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppThemeColors.success.withValues(alpha: 0.1),
                  borderRadius: AppRadius.fullRadius,
                ),
                child: Text(
                  'Hadir',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppThemeColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppThemeColors.divider),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.checklist,
                size: 16,
                color: AppThemeColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Checklist: $checkedCount / $checklistCount',
                style: AppTypography.bodySmall,
              ),
              const Spacer(),
              if (attendance.checklistDurationSec != null)
                Row(
                  children: [
                    const Icon(
                      Icons.timer,
                      size: 16,
                      color: AppThemeColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${attendance.checklistDurationSec}s',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
