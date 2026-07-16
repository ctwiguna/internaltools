import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/theme/app_theme.dart';
import 'package:flutter_laundry_offline_app/data/models/outlet.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/outlet/outlet_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/outlet/outlet_state.dart';

/// Widget to display current outlet and allow switching between outlets
class OutletSelectorWidget extends StatelessWidget {
  final bool showCreateButton;
  final VoidCallback? onOutletChanged;

  const OutletSelectorWidget({
    super.key,
    this.showCreateButton = true,
    this.onOutletChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OutletCubit, OutletState>(
      listener: (context, state) {
        if (state is OutletSwitched) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppThemeColors.success,
            ),
          );
          onOutletChanged?.call();
        } else if (state is OutletError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppThemeColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is OutletLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state is OutletLoaded) {
          return _buildOutletSelector(context, state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildOutletSelector(BuildContext context, OutletLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current outlet card
        if (state.currentOutlet != null)
          _buildCurrentOutletCard(context, state.currentOutlet!),

        const SizedBox(height: AppSpacing.md),

        // Outlet list if more than 1
        if (state.outlets.length > 1) ...[
          Text(
            'Outlet Lainnya',
            style: AppTypography.labelMedium.copyWith(
              color: AppThemeColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...state.outlets
              .where((o) => o.id != state.currentOutlet?.id)
              .map((outlet) => _buildOutletTile(context, outlet)),
        ],

        // Create new outlet button
        if (showCreateButton) ...[
          const SizedBox(height: AppSpacing.md),
          _buildCreateOutletButton(context),
        ],
      ],
    );
  }

  Widget _buildCurrentOutletCard(BuildContext context, Outlet outlet) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppThemeColors.primaryGradient,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: AppRadius.mdRadius,
            ),
            child: const Icon(
              Icons.store,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        outlet.name,
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Text(
                        'AKTIF',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (outlet.address != null && outlet.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    outlet.address!,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletTile(BuildContext context, Outlet outlet) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppThemeColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppThemeColors.primaryLight,
            borderRadius: AppRadius.smRadius,
          ),
          child: const Icon(
            Icons.store_outlined,
            color: AppThemeColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          outlet.name,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: outlet.address != null && outlet.address!.isNotEmpty
            ? Text(
                outlet.address!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppThemeColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: TextButton(
          onPressed: () => _switchOutlet(context, outlet),
          child: const Text('Pilih'),
        ),
        onTap: () => _switchOutlet(context, outlet),
      ),
    );
  }

  Widget _buildCreateOutletButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showCreateOutletDialog(context),
      icon: const Icon(Icons.add),
      label: const Text('Tambah Outlet Baru'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppThemeColors.primary,
        side: const BorderSide(color: AppThemeColors.primary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
        ),
      ),
    );
  }

  void _switchOutlet(BuildContext context, Outlet outlet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Outlet'),
        content: Text('Apakah Anda yakin ingin beralih ke "${outlet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OutletCubit>().switchOutlet(outlet);
            },
            child: const Text('Ya, Ganti'),
          ),
        ],
      ),
    );
  }

  void _showCreateOutletDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final prefixController = TextEditingController(text: 'INV');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Outlet Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Outlet *',
                  hintText: 'Contoh: Laundry Cabang 2',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  hintText: 'Alamat outlet',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'No. Telepon',
                  hintText: '08xxxxxxxxxx',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: prefixController,
                decoration: const InputDecoration(
                  labelText: 'Prefix Invoice',
                  hintText: 'Contoh: INV, LND',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nama outlet tidak boleh kosong'),
                    backgroundColor: AppThemeColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              context.read<OutletCubit>().createOutlet(
                    name: nameController.text,
                    address: addressController.text,
                    phone: phoneController.text,
                    invoicePrefix: prefixController.text,
                  );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

/// Compact outlet indicator for app bar or header
class OutletIndicator extends StatelessWidget {
  final VoidCallback? onTap;

  const OutletIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OutletCubit, OutletState>(
      builder: (context, state) {
        if (state is OutletLoaded && state.currentOutlet != null) {
          final outlet = state.currentOutlet!;
          final hasMultiple = state.outlets.length > 1;

          return GestureDetector(
            onTap: hasMultiple ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: AppRadius.smRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.store,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    outlet.name,
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasMultiple) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
