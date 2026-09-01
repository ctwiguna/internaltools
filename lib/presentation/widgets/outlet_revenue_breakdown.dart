import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/cubits/auth/auth_cubit.dart';
import '../../logic/cubits/auth/auth_state.dart';

/// "Total Omzet" & "Total Transaksi Cash" PER OUTLET untuk rentang tanggal
/// laporan yang sedang dipilih. Hanya tampil untuk akun owner (ctwiguna);
/// akun outlet lain tidak melihat apa-apa (laporan mereka sudah otomatis
/// terfilter ke outlet sendiri).
class OutletRevenueBreakdown extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;

  const OutletRevenueBreakdown({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  bool _isOwner(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      return state.user.username.split('@').first.toLowerCase() == 'ctwiguna';
    }
    return false;
  }

  Future<List<_OutletRevenue>> _load() async {
    final client = SupabaseService.instance.client;

    final outletRows =
        await client.from('outlets').select('id, name').order('name');

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    // Total omzet per outlet (nilai order dalam rentang tanggal)
    final orderRows = await client
        .from('orders')
        .select('outlet_id, total_price')
        .gte('order_date', startStr)
        .lte('order_date', endStr);

    // Total transaksi cash per outlet (pembayaran diterima dalam rentang tanggal)
    final paymentRows = await client
        .from('payments')
        .select('amount, change_amount, payment_date, orders!inner(outlet_id)')
        .gte('payment_date', startStr)
        .lte('payment_date', endStr);

    final Map<String, int> omzetPerOutlet = {};
    for (final row in orderRows as List) {
      final outletId = row['outlet_id'] as String?;
      if (outletId == null) continue;
      final total = (row['total_price'] as num?)?.toInt() ?? 0;
      omzetPerOutlet[outletId] = (omzetPerOutlet[outletId] ?? 0) + total;
    }

    final Map<String, int> cashPerOutlet = {};
    for (final row in paymentRows as List) {
      final outletId = (row['orders'] as Map)['outlet_id'] as String?;
      if (outletId == null) continue;
      final amount = (row['amount'] as num?)?.toInt() ?? 0;
      final change = (row['change_amount'] as num?)?.toInt() ?? 0;
      cashPerOutlet[outletId] = (cashPerOutlet[outletId] ?? 0) + (amount - change);
    }

    return [
      for (final o in outletRows as List)
        _OutletRevenue(
          outletName: o['name'] as String? ?? '-',
          totalOmzet: omzetPerOutlet[o['id']] ?? 0,
          totalCash: cashPerOutlet[o['id']] ?? 0,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner(context)) return const SizedBox.shrink();

    return FutureBuilder<List<_OutletRevenue>>(
      // Rebuild query saat rentang tanggal berubah.
      key: ValueKey('$startDate-$endDate'),
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Gagal memuat omzet per outlet: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          );
        }

        final rows = snapshot.data!;
        if (rows.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows) ...[
              _buildOutletCard(r),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOutletCard(_OutletRevenue r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.outletName,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Total Omzet',
                  CurrencyFormatter.formatCompact(r.totalOmzet),
                  AppThemeColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _miniStat(
                  'Total Transaksi Cash',
                  CurrencyFormatter.formatCompact(r.totalCash),
                  AppThemeColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppThemeColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _OutletRevenue {
  final String outletName;
  final int totalOmzet;
  final int totalCash;

  const _OutletRevenue({
    required this.outletName,
    required this.totalOmzet,
    required this.totalCash,
  });
}
