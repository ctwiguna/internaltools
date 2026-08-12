import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/theme/app_theme.dart';
import 'package:flutter_laundry_offline_app/core/utils/currency_formatter.dart';
import 'package:flutter_laundry_offline_app/core/utils/date_formatter.dart';
import 'package:flutter_laundry_offline_app/data/models/cancellation_request.dart';
import 'package:flutter_laundry_offline_app/data/models/user.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_state.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/cancellation/cancellation_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/cancellation/cancellation_state.dart';

/// Detail pengajuan pembatalan — render dari snapshot (order sudah dihapus
/// begitu request di-approve, jadi ini satu-satunya sumber data).
/// Tombol Setujui/Tolak hanya muncul untuk [ownerMode] pada request pending.
class CancellationDetailScreen extends StatefulWidget {
  final CancellationRequest request;
  final bool ownerMode;

  const CancellationDetailScreen({
    super.key,
    required this.request,
    this.ownerMode = true,
  });

  @override
  State<CancellationDetailScreen> createState() => _CancellationDetailScreenState();
}

class _CancellationDetailScreenState extends State<CancellationDetailScreen> {
  bool _busy = false;

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

  User? get _currentUser {
    final authState = context.read<AuthCubit>().state;
    return authState is AuthAuthenticated ? authState.user : null;
  }

  Future<void> _confirmApprove() async {
    final reviewer = _currentUser;
    if (reviewer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Text('Setujui Pembatalan', style: AppTypography.titleLarge),
        content: Text(
          'Order ${widget.request.invoiceNo} akan dihapus permanen dari data order aktif. '
          'Riwayat pembatalannya tetap tersimpan di sini. Lanjutkan?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Batal',
              style: AppTypography.labelMedium.copyWith(color: AppThemeColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.error,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
            ),
            child: Text('Setujui', style: AppTypography.labelMedium.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await context.read<CancellationCubit>().approve(widget.request, reviewer: reviewer);
    if (!mounted) return;
    _handleReviewResult();
  }

  Future<void> _confirmReject() async {
    final reviewer = _currentUser;
    if (reviewer == null) return;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Text('Tolak Pengajuan', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ${widget.request.invoiceNo} akan tetap aktif seperti semula.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Batal',
              style: AppTypography.labelMedium.copyWith(color: AppThemeColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
            ),
            child: Text('Tolak', style: AppTypography.labelMedium.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await context.read<CancellationCubit>().reject(
          widget.request,
          reviewer: reviewer,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        );
    if (!mounted) return;
    _handleReviewResult();
  }

  void _handleReviewResult() {
    final state = context.read<CancellationCubit>().state;
    setState(() => _busy = false);

    if (state is CancellationReviewSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: AppThemeColors.success),
      );
      Navigator.pop(context);
    } else if (state is CancellationError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: AppThemeColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final snapshot = request.orderSnapshot;
    final items = (snapshot['items'] as List?) ?? [];
    final payments = (snapshot['payments'] as List?) ?? [];
    final color = _statusColor(request.status);

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: Column(
        children: [
          _buildHeader(request, color),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _buildInfoCard(request, color),
                const SizedBox(height: AppSpacing.md),
                _buildItemsCard(items),
                if (payments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildPaymentsCard(payments),
                ],
                if (request.status != CancellationStatus.pending) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildReviewCard(request, color),
                ],
                if (request.status == CancellationStatus.pending && widget.ownerMode) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildActionButtons(),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CancellationRequest request, Color color) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengajuan Pembatalan',
                      style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                    ),
                    Text(
                      request.invoiceNo,
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(CancellationRequest request, Color color) {
    return Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.customerName,
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
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
            if (request.customerPhone != null) ...[
              const SizedBox(height: 2),
              Text(
                request.customerPhone!,
                style: AppTypography.bodySmall.copyWith(color: AppThemeColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Container(height: 1, color: AppThemeColors.divider),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppTypography.bodyMedium),
                Text(
                  CurrencyFormatter.format(request.totalPrice),
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sudah Dibayar', style: AppTypography.bodyMedium),
                Text(
                  CurrencyFormatter.format(request.paid),
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(height: 1, color: AppThemeColors.divider),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Alasan Pembatalan',
              style: AppTypography.labelMedium.copyWith(
                color: AppThemeColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(request.reason, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Diajukan oleh ${request.requestedByName}'
              '${request.createdAt != null ? ' • ${DateFormatter.formatDateTime(request.createdAt!)}' : ''}',
              style: AppTypography.labelSmall.copyWith(color: AppThemeColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(List items) {
    return Container(
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
            Text(
              'Item',
              style: AppTypography.labelMedium.copyWith(
                color: AppThemeColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...items.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['service_name']} (${item['quantity']} ${item['unit']})',
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format((item['subtotal'] as num?)?.toInt() ?? 0),
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsCard(List payments) {
    return Container(
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
            Text(
              'Pembayaran',
              style: AppTypography.labelMedium.copyWith(
                color: AppThemeColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...payments.map((raw) {
              final payment = Map<String, dynamic>.from(raw as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${payment['payment_method']}',
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format((payment['amount'] as num?)?.toInt() ?? 0),
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(CancellationRequest request, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Direview oleh ${request.reviewedByName ?? '-'}'
              '${request.reviewedAt != null ? ' • ${DateFormatter.formatDateTime(request.reviewedAt!)}' : ''}',
              style: AppTypography.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (request.reviewNote != null && request.reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Catatan: ${request.reviewNote}', style: AppTypography.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : _confirmReject,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppThemeColors.border),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
            ),
            child: Text(
              'Tolak',
              style: AppTypography.labelMedium.copyWith(color: AppThemeColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatedButton(
            onPressed: _busy ? null : _confirmApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.error,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Setujui',
                    style: AppTypography.labelMedium.copyWith(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}
