import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/supabase_service.dart';
import '../../../logic/cubits/auth/auth_cubit.dart';
import '../../../logic/cubits/auth/auth_state.dart';

/// Kartu ringkasan omzet & jumlah order HARI INI untuk semua outlet.
/// Hanya tampil untuk akun owner (ctwiguna); akun lain tidak melihat apa-apa.
///
/// Widget ini berdiri sendiri: query langsung ke Supabase, tidak mengubah
/// ReportData / ReportCubit yang sudah ada.
class MultiOutletSummarySection extends StatelessWidget {
  const MultiOutletSummarySection({super.key});

  bool _isOwner(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      return state.user.username.split('@').first.toLowerCase() == 'ctwiguna';
    }
    return false;
  }

  Future<List<_OutletDailySummary>> _load() async {
    final client = SupabaseService.instance.client;

    // 1. Semua outlet
    final outletRows =
        await client.from('outlets').select('id, name').order('name');

    // 2. Rentang "hari ini" (waktu lokal perangkat -> UTC untuk timestamptz)
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final gte = todayStart.toUtc().toIso8601String();
    final lt = tomorrowStart.toUtc().toIso8601String();

    // 3. Pembayaran hari ini (join orders untuk dapat outlet_id)
    final paymentRows = await client
        .from('payments')
        .select('amount, orders!inner(outlet_id)')
        .gte('created_at', gte)
        .lt('created_at', lt);

    // 4. Order hari ini (untuk jumlah order per outlet)
    final orderRows = await client
        .from('orders')
        .select('id, outlet_id')
        .gte('created_at', gte)
        .lt('created_at', lt);

    // 5. Kelompokkan per outlet di Dart
    final Map<String, double> omzetPerOutlet = {};
    for (final row in paymentRows as List) {
      final outletId = (row['orders'] as Map)['outlet_id'] as String?;
      if (outletId == null) continue;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      omzetPerOutlet[outletId] = (omzetPerOutlet[outletId] ?? 0) + amount;
    }

    final Map<String, int> orderCountPerOutlet = {};
    for (final row in orderRows as List) {
      final outletId = row['outlet_id'] as String?;
      if (outletId == null) continue;
      orderCountPerOutlet[outletId] = (orderCountPerOutlet[outletId] ?? 0) + 1;
    }

    return [
      for (final o in outletRows as List)
        _OutletDailySummary(
          outletId: o['id'] as String,
          outletName: o['name'] as String? ?? '-',
          todayOmzet: omzetPerOutlet[o['id']] ?? 0,
          todayOrderCount: orderCountPerOutlet[o['id']] ?? 0,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner(context)) return const SizedBox.shrink();

    return FutureBuilder<List<_OutletDailySummary>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Gagal memuat ringkasan outlet: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final summaries = snapshot.data!;
        if (summaries.isEmpty) return const SizedBox.shrink();

        final totalOmzet =
            summaries.fold<double>(0, (sum, s) => sum + s.todayOmzet);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Omzet Hari Ini — Semua Outlet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: summaries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final s = summaries[index];
                  return _OutletSummaryCard(summary: s);
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total semua outlet: ${_formatRupiah(totalOmzet)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _OutletDailySummary {
  final String outletId;
  final String outletName;
  final double todayOmzet;
  final int todayOrderCount;

  const _OutletDailySummary({
    required this.outletId,
    required this.outletName,
    required this.todayOmzet,
    required this.todayOrderCount,
  });
}

class _OutletSummaryCard extends StatelessWidget {
  final _OutletDailySummary summary;

  const _OutletSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.outletName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              _formatRupiah(summary.todayOmzet),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${summary.todayOrderCount} order',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Format angka ke "Rp 25.000" tanpa dependensi intl.
String _formatRupiah(double value) {
  final intVal = value.round();
  final digits = intVal.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
  }
  return 'Rp $buffer';
}
