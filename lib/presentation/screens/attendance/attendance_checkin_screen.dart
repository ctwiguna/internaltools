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
    {'item': 'Lantai dipel', 'checked': false},
    {'item': 'Meja kasir dilap', 'checked': false},
    {'item': 'Peralatan cuci dicek', 'checked': false},
    {'item': 'Stok deterjen dicek', 'checked': false},
    {'item': 'Tempat sampah dikosongkan', 'checked': false},
    {'item': 'Setrika dicek', 'checked': false},
    {'item': 'Mesin cuci dicek', 'checked': false},
    {'item': 'Lemari pelanggan dirapikan', 'checked': false},
  ];

  bool _isSubmitting = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  bool get _allChecked => _checklistItems.every((i) => i['checked'] == true);

  int get _checkedCount => _checklistItems.where((i) => i['checked'] == true).length;

  void _toggleItem(int index, bool? value) {
    setState(() {
      _checklistItems[index]['checked'] = value ?? false;
      _checklistItems[index]['checked_at'] = DateTime.now().toIso8601String();
    });
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
    final checklist = _checklistItems.map((i) => {
      'item': i['item'] as String,
      'checked_at': i['checked_at'] as String? ?? DateTime.now().toIso8601String(),
    }).toList();

    setState(() => _isSubmitting = true);

    context.read<AttendanceCubit>().checkIn(
      userId: user.id,
      userName: user.name,
      checklist: checklist.cast<Map<String, String>>(),
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
            Navigator.pop(context, true);
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
