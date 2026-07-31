import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/constants/app_constants.dart';
import 'package:flutter_laundry_offline_app/core/theme/app_theme.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/attendance/attendance_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/attendance/attendance_state.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_state.dart';
import 'package:intl/intl.dart';

class AttendanceCheckInScreen extends StatefulWidget {
  const AttendanceCheckInScreen({super.key});

  @override
  State<AttendanceCheckInScreen> createState() => _AttendanceCheckInScreenState();
}

class _AttendanceCheckInScreenState extends State<AttendanceCheckInScreen> {
  final List<Map<String, dynamic>> _checklistItems = [
    {'item': 'Sapu & pel', 'checked': false},
    {'item': 'Karet dan kaca mesin cuci dilap', 'checked': false},
    {'item': 'Drop off sudah dikerjakan', 'checked': false},
    {'item': 'Stok deterjen pewangi plastik ada', 'checked': false},
    {'item': 'Tempat sampah dikosongkan', 'checked': false},
    {'item': 'Saldo token listrik di atas 200', 'checked': false},
    {'item': 'Gas LPG masih', 'checked': false},
    {'item': 'Lemari, meja, toilet dirapikan', 'checked': false},
  ];

  final TextEditingController _lipatController = TextEditingController();
  final TextEditingController _setrikaController = TextEditingController();

  bool _isSubmitting = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    _lipatController.dispose();
    _setrikaController.dispose();
    super.dispose();
  }

  bool get _allChecked => _checklistItems.every((i) => i['checked'] == true);

  int get _checkedCount => _checklistItems.where((i) => i['checked'] == true).length;

  void _toggleItem(int index, bool? value) {
    setState(() {
      _checklistItems[index]['checked'] = value ?? false;
      _checklistItems[index]['checked_at'] = DateTime.now().toIso8601String();
    });
  }

  double _parseKg(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return 0;
    return double.tryParse(normalized) ?? 0;
  }

  void _submit() {
    if (!_allChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap centang semua checklist terlebih dahulu'),
          backgroundColor: AppThemeColors.warning,
        ),
      );
      return;
    }

    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    final user = authState.user;
    final durationSec = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0;
    final checklist = _checklistItems.map((i) => {
      'item': i['item'] as String,
      'checked': 'true',
      'checked_at': i['checked_at'] as String? ?? DateTime.now().toIso8601String(),
    }).toList();

    setState(() => _isSubmitting = true);

    context.read<AttendanceCubit>().checkIn(
      userId: user.id,
      userRemoteId: user.remoteId,
      userName: user.name,
      checklist: checklist.cast<Map<String, String>>(),
      durationSec: durationSec,
      lipatKg: _parseKg(_lipatController.text),
      setrikaKg: _parseKg(_setrikaController.text),
    );
  }

  Widget _buildKgField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTypography.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodySmall
            .copyWith(color: AppThemeColors.textSecondary),
        prefixIcon: Icon(icon, color: AppThemeColors.primary, size: 20),
        suffixText: 'kg',
        suffixStyle: AppTypography.bodySmall
            .copyWith(color: AppThemeColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppThemeColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppThemeColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppThemeColors.primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        title: const Text('Absensi Masuk'),
        centerTitle: true,
      ),
      body: BlocConsumer<AttendanceCubit, AttendanceState>(
        listener: (context, state) {
          if (state is AttendanceCheckInSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.success,
              ),
            );
            Navigator.pop(context);
          } else if (state is AttendanceError) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Header info
              Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppThemeColors.primaryGradient,
                  borderRadius: AppRadius.lgRadius,
                  boxShadow: AppShadows.purple,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          DateFormat(AppConstants.dateFormat).format(DateTime.now()),
                          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          DateFormat(AppConstants.timeFormat).format(DateTime.now()),
                          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LinearProgressIndicator(
                      value: _checkedCount / _checklistItems.length,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      borderRadius: AppRadius.fullRadius,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '$_checkedCount / ${_checklistItems.length} checklist selesai',
                      style: AppTypography.labelMedium.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Checklist
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: _checklistItems.length,
                  itemBuilder: (context, index) {
                    final item = _checklistItems[index];
                    final isChecked = item['checked'] == true;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isChecked ? AppThemeColors.primarySurface : Colors.white,
                        borderRadius: AppRadius.mdRadius,
                        border: Border.all(
                          color: isChecked ? AppThemeColors.primary : AppThemeColors.border,
                        ),
                        boxShadow: AppShadows.small,
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        onChanged: (v) => _toggleItem(index, v),
                        activeColor: AppThemeColors.primary,
                        checkColor: Colors.white,
                        title: Text(
                          item['item'] as String,
                          style: AppTypography.bodyMedium.copyWith(
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked
                                ? AppThemeColors.textSecondary
                                : AppThemeColors.textPrimary,
                          ),
                        ),
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isChecked
                                ? AppThemeColors.primary
                                : AppThemeColors.primarySurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isChecked ? Icons.check : Icons.radio_button_unchecked,
                            color: isChecked ? Colors.white : AppThemeColors.primary,
                            size: 20,
                          ),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                      ),
                    );
                  },
                ),
              ),

              // Laporan kinerja (kg) — opsional
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: AppThemeColors.border),
                  boxShadow: AppShadows.small,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.scale_outlined,
                            color: AppThemeColors.primary, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Laporan Kinerja Hari Ini (opsional)',
                          style: AppTypography.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildKgField(
                      controller: _lipatController,
                      label: 'Lipat, packing, wangi',
                      icon: Icons.dry_cleaning_outlined,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildKgField(
                      controller: _setrikaController,
                      label: 'Setrika',
                      icon: Icons.iron_outlined,
                    ),
                  ],
                ),
              ),

              // Submit button
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting || state is AttendanceLoading ? null : _submit,
                    icon: _isSubmitting || state is AttendanceLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login, color: Colors.white),
                    label: Text(
                      _isSubmitting || state is AttendanceLoading
                          ? 'Menyimpan...'
                          : 'Catat Absensi Masuk',
                      style: AppTypography.button,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
