import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/outlet_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../logic/cubits/auth/auth_cubit.dart';
import '../../../logic/cubits/auth/auth_state.dart';

/// Kartu "Uang Laci Kasir":
///   uang laci awal (diinput owner) + transaksi cash hari ini = total laci.
///
/// - Mengikuti outlet aktif (OutletService).
/// - Semua akun bisa melihat angkanya.
/// - Hanya owner (ctwiguna) yang bisa menginput/koreksi laci awal,
///   untuk hari ini atau besok (misal input malam sebelumnya).
class CashDrawerCard extends StatefulWidget {
  const CashDrawerCard({super.key});

  @override
  State<CashDrawerCard> createState() => _CashDrawerCardState();
}

class _CashDrawerCardState extends State<CashDrawerCard> {
  int _reloadToken = 0;

  bool get _isOwner {
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      return state.user.username.split('@').first.toLowerCase() == 'ctwiguna';
    }
    return false;
  }

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<_CashDrawerData> _load() async {
    final client = SupabaseService.instance.client;
    final outletUuid = OutletService.instance.currentOutletUuid;
    if (outletUuid == null) {
      return const _CashDrawerData(openingCash: 0, cashToday: 0);
    }

    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    // 1. Laci awal hari ini
    final drawerRows = await client
        .from('cash_drawer')
        .select('opening_cash')
        .eq('outlet_id', outletUuid)
        .eq('date', todayKey)
        .limit(1);
    final openingCash = (drawerRows as List).isEmpty
        ? 0
        : ((drawerRows.first['opening_cash'] as num?)?.toInt() ?? 0);

    // 2. Total pembayaran CASH hari ini (net: amount - kembalian)
    final paymentRows = await client
        .from('payments')
        .select('amount, change_amount, orders!inner(outlet_id)')
        .eq('payment_method', 'cash')
        .eq('orders.outlet_id', outletUuid)
        .gte('payment_date', startOfDay.toIso8601String())
        .lte('payment_date', endOfDay.toIso8601String());

    int cashToday = 0;
    for (final row in paymentRows as List) {
      final amount = (row['amount'] as num?)?.toInt() ?? 0;
      final change = (row['change_amount'] as num?)?.toInt() ?? 0;
      cashToday += amount - change;
    }

    return _CashDrawerData(openingCash: openingCash, cashToday: cashToday);
  }

  Future<void> _showSetOpeningDialog(int currentOpening) async {
    final amountController =
        TextEditingController(text: currentOpening > 0 ? '$currentOpening' : '');
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final tomorrowKey = _dateKey(now.add(const Duration(days: 1)));
    String selectedDate = todayKey;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set Uang Laci Awal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedDate,
                    decoration: const InputDecoration(
                      labelText: 'Berlaku untuk tanggal',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: todayKey,
                        child: Text('Hari ini ($todayKey)'),
                      ),
                      DropdownMenuItem(
                        value: tomorrowKey,
                        child: Text('Besok ($tomorrowKey)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedDate = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Jumlah uang laci awal',
                      prefixText: 'Rp ',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = int.tryParse(amountController.text) ?? 0;
                    final outletUuid =
                        OutletService.instance.currentOutletUuid;
                    if (outletUuid == null) {
                      Navigator.pop(dialogContext, false);
                      return;
                    }
                    final client = SupabaseService.instance.client;
                    final authState = context.read<AuthCubit>().state;
                    final userName = authState is AuthAuthenticated
                        ? authState.user.name
                        : null;
                    await client.from('cash_drawer').upsert(
                      {
                        'outlet_id': outletUuid,
                        'date': selectedDate,
                        'opening_cash': amount,
                        'set_by': client.auth.currentUser?.id,
                        'set_by_name': userName,
                        'updated_at': DateTime.now().toIso8601String(),
                      },
                      onConflict: 'outlet_id,date',
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      setState(() => _reloadToken++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CashDrawerData>(
      key: ValueKey(_reloadToken),
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final opening = data?.openingCash ?? 0;
        final cashToday = data?.cashToday ?? 0;
        final total = opening + cashToday;

        return Container(
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
                    decoration: const BoxDecoration(
                      color: AppThemeColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.point_of_sale,
                      color: AppThemeColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Uang Laci Kasir',
                      style: AppTypography.titleLarge,
                    ),
                  ),
                  if (_isOwner)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppThemeColors.primary),
                      tooltip: 'Set uang laci awal',
                      onPressed: () => _showSetOpeningDialog(opening),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _buildRow('Laci awal', opening),
              const SizedBox(height: AppSpacing.xs),
              _buildRow('Cash hari ini', cashToday),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
              _buildRow('Total uang laci', total, isTotal: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(String label, int amount, {bool isTotal = false}) {
    final style = isTotal
        ? AppTypography.titleLarge.copyWith(color: AppThemeColors.primary)
        : AppTypography.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: isTotal
                ? style
                : AppTypography.bodyMedium
                    .copyWith(color: AppThemeColors.textSecondary)),
        Text(_formatRupiah(amount), style: style),
      ],
    );
  }

  static String _formatRupiah(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    return 'Rp $buffer';
  }
}

class _CashDrawerData {
  final int openingCash;
  final int cashToday;

  const _CashDrawerData({required this.openingCash, required this.cashToday});
}
