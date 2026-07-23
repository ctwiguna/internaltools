import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/theme/app_theme.dart';
import 'package:flutter_laundry_offline_app/data/models/outlet.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/outlet/outlet_cubit.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/outlet/outlet_state.dart';

class OutletManagementScreen extends StatefulWidget {
  const OutletManagementScreen({super.key});

  @override
  State<OutletManagementScreen> createState() => _OutletManagementScreenState();
}

class _OutletManagementScreenState extends State<OutletManagementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OutletCubit>().loadOutlets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: BlocConsumer<OutletCubit, OutletState>(
        listener: (context, state) {
          if (state is OutletSwitched) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.success,
              ),
            );
          } else if (state is OutletCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.success,
              ),
            );
          } else if (state is OutletUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppThemeColors.success,
              ),
            );
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
          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _buildContent(context, state),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOutletDialog(context),
        backgroundColor: AppThemeColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah Outlet',
          style: AppTypography.labelMedium.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Kelola Outlet',
                  style: AppTypography.headlineMedium.copyWith(
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

  Widget _buildContent(BuildContext context, OutletState state) {
    if (state is OutletLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state is OutletLoaded) {
      return _buildOutletList(context, state);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_outlined,
            size: 64,
            color: AppThemeColors.textHint,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Belum ada outlet',
            style: AppTypography.bodyLarge.copyWith(
              color: AppThemeColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => _showCreateOutletDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Outlet'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletList(BuildContext context, OutletLoaded state) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.outlets.length,
      itemBuilder: (context, index) {
        final outlet = state.outlets[index];
        final isCurrentOutlet = outlet.remoteId != null
            ? outlet.remoteId == state.currentOutlet?.remoteId
            : outlet.id == state.currentOutlet?.id;

        return _buildOutletCard(context, outlet, isCurrentOutlet, state.outlets.length);
      },
    );
  }

  Widget _buildOutletCard(
    BuildContext context,
    Outlet outlet,
    bool isCurrentOutlet,
    int totalOutlets,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgRadius,
        border: isCurrentOutlet
            ? Border.all(color: AppThemeColors.primary, width: 2)
            : null,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          // Header with outlet info
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: isCurrentOutlet
                ? BoxDecoration(
                    gradient: AppThemeColors.primaryGradient,
                    borderRadius: BorderRadius.only(
                      topLeft: AppRadius.lgRadius.topLeft,
                      topRight: AppRadius.lgRadius.topRight,
                    ),
                  )
                : null,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCurrentOutlet
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppThemeColors.primaryLight,
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: Icon(
                    Icons.store,
                    color: isCurrentOutlet ? Colors.white : AppThemeColors.primary,
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
                                color: isCurrentOutlet
                                    ? Colors.white
                                    : AppThemeColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentOutlet)
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
                      if (outlet.address != null &&
                          outlet.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          outlet.address!,
                          style: AppTypography.bodySmall.copyWith(
                            color: isCurrentOutlet
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppThemeColors.textSecondary,
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
          ),

          // Outlet details
          if (!isCurrentOutlet)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  if (outlet.phone != null && outlet.phone!.isNotEmpty)
                    _buildDetailRow(
                      Icons.phone,
                      'Telepon',
                      outlet.phone!,
                    ),
                  _buildDetailRow(
                    Icons.receipt,
                    'Prefix Invoice',
                    outlet.invoicePrefix,
                  ),
                ],
              ),
            ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppThemeColors.background,
              borderRadius: BorderRadius.only(
                bottomLeft: AppRadius.lgRadius.bottomLeft,
                bottomRight: AppRadius.lgRadius.bottomRight,
              ),
            ),
            child: Row(
              children: [
                if (!isCurrentOutlet)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _switchOutlet(context, outlet),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Pilih'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppThemeColors.primary,
                        side: const BorderSide(color: AppThemeColors.primary),
                      ),
                    ),
                  ),
                if (!isCurrentOutlet) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditOutletDialog(context, outlet),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeColors.textSecondary,
                    ),
                  ),
                ),
                if (!isCurrentOutlet && totalOutlets > 1) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(context, outlet),
                    icon: const Icon(Icons.delete_outline),
                    color: AppThemeColors.error,
                    tooltip: 'Hapus outlet',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppThemeColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label:',
            style: AppTypography.bodySmall.copyWith(
              color: AppThemeColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: AppThemeColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Outlet Baru'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Outlet *',
                    hintText: 'Contoh: Laundry Cabang 2',
                    prefixIcon: Icon(Icons.store),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama outlet tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    hintText: 'Alamat outlet',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'No. Telepon',
                    hintText: '08xxxxxxxxxx',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: prefixController,
                  decoration: const InputDecoration(
                    labelText: 'Prefix Invoice',
                    hintText: 'Contoh: INV, LND',
                    prefixIcon: Icon(Icons.receipt),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                context.read<OutletCubit>().createOutlet(
                      name: nameController.text,
                      address: addressController.text.isNotEmpty
                          ? addressController.text
                          : null,
                      phone: phoneController.text.isNotEmpty
                          ? phoneController.text
                          : null,
                      invoicePrefix: prefixController.text.isNotEmpty
                          ? prefixController.text
                          : 'INV',
                    );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditOutletDialog(BuildContext context, Outlet outlet) {
    final nameController = TextEditingController(text: outlet.name);
    final addressController = TextEditingController(text: outlet.address ?? '');
    final phoneController = TextEditingController(text: outlet.phone ?? '');
    final prefixController =
        TextEditingController(text: outlet.invoicePrefix);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Outlet'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Outlet *',
                    hintText: 'Contoh: Laundry Cabang 2',
                    prefixIcon: Icon(Icons.store),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama outlet tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    hintText: 'Alamat outlet',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'No. Telepon',
                    hintText: '08xxxxxxxxxx',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: prefixController,
                  decoration: const InputDecoration(
                    labelText: 'Prefix Invoice',
                    hintText: 'Contoh: INV, LND',
                    prefixIcon: Icon(Icons.receipt),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                context.read<OutletCubit>().updateOutlet(
                      outlet.copyWith(
                        name: nameController.text.trim(),
                        address: addressController.text.isNotEmpty
                            ? addressController.text.trim()
                            : null,
                        phone: phoneController.text.isNotEmpty
                            ? phoneController.text.trim()
                            : null,
                        invoicePrefix: prefixController.text.isNotEmpty
                            ? prefixController.text.trim().toUpperCase()
                            : 'INV',
                      ),
                    );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Outlet outlet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Outlet'),
        content: Text(
          'Apakah Anda yakin ingin menghapus outlet "${outlet.name}"?\n\n'
          'Perhatian: Data yang terkait dengan outlet ini mungkin tidak dapat diakses lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OutletCubit>().deleteOutlet(outlet.remoteId ?? outlet.id!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.error,
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }
}
