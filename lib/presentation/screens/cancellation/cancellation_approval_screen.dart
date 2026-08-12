import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/theme/app_theme.dart';
import 'package:flutter_laundry_offline_app/core/utils/currency_formatter.dart';
import 'package:flutter_laundry_offline_app/core/utils/date_formatter.dart';
import 'package:flutter_laundry_offline_app/data/models/cancellation_request.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_state.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/cancellation/cancellation_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/cancellation/cancellation_state.dart';
import 'package:flutter_laundry_offline_app/presentation/screens/cancellation/cancellation_detail_screen.dart';

/// Daftar pengajuan pembatalan order.
/// [ownerMode] true: owner mereview semua pengajuan outlet aktif.
/// [ownerMode] false: kasir melihat riwayat pengajuannya sendiri saja.
class CancellationApprovalScreen extends StatefulWidget {
  final bool ownerMode;

  const CancellationApprovalScreen({super.key, this.ownerMode = true});

  @override
  State<CancellationApprovalScreen> createState() =>
      _CancellationApprovalScreenState();
}

class _CancellationApprovalScreenState
    extends State<CancellationApprovalScreen> {
  CancellationStatus? _selectedStatus = CancellationStatus.pending;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    final authState = context.read<AuthCubit>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    context.read<CancellationCubit>().loadRequests(
          status: _selectedStatus,
          onlyMine: !widget.ownerMode,
          currentUser: user,
        );
  }

  void _onStatusChanged(CancellationStatus? status) {
    setState(() => _selectedStatus = status);
    _loadRequests();
  }

  Color _statusColor(CancellationStatus status) {
    switch (status) {
      case CancellationStatus.pending:
        return AppThemeColors.warning;
      case CancellationStatus.approved:
        return AppThemeColors.error;
      case CancellationStatus.rejected:
        return AppThemeColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterChips(),
          Expanded(
            child: BlocConsumer<CancellationCubit, CancellationState>(
              listener: (context, state) {
                if (state is CancellationError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppThemeColors.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is CancellationLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppThemeColors.primary),
                  );
                }

                final requests =
                    state is CancellationLoaded ? state.requests : <CancellationRequest>[];

                if (requests.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadRequests(),
                  color: AppThemeColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _buildRequestCard(request),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppThemeColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.ownerMode ? 'Persetujuan Pembatalan' : 'Riwayat Pembatalan Saya',
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Menunggu',
              status: CancellationStatus.pending,
              color: AppThemeColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildFilterChip(
              label: 'Dibatalkan',
              status: CancellationStatus.approved,
              color: AppThemeColors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildFilterChip(
              label: 'Ditolak',
              status: CancellationStatus.rejected,
              color: AppThemeColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildFilterChip(label: 'Semua', status: null, color: AppThemeColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required CancellationStatus? status,
    required Color color,
  }) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => _onStatusChanged(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: AppRadius.fullRadius,
          border: Border.all(color: isSelected ? color : AppThemeColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? Colors.white : AppThemeColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppThemeColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_late_outlined,
                size: 40,
                color: AppThemeColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Belum ada pengajuan pembatalan',
              style: AppTypography.titleMedium.copyWith(color: AppThemeColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(CancellationRequest request) {
    final color = _statusColor(request.status);
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<CancellationCubit>(),
              child: CancellationDetailScreen(request: request, ownerMode: widget.ownerMode),
            ),
          ),
        );
        _loadRequests();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgRadius,
          boxShadow: AppShadows.small,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.invoiceNo,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppThemeColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: AppRadius.fullRadius,
                    ),
                    child: Text(
                      request.status.displayName,
                      style: AppTypography.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(request.customerName, style: AppTypography.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                CurrencyFormatter.format(request.totalPrice),
                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Diajukan oleh ${request.requestedByName}'
                '${request.createdAt != null ? ' • ${DateFormatter.formatDateTime(request.createdAt!)}' : ''}',
                style: AppTypography.labelSmall.copyWith(color: AppThemeColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
