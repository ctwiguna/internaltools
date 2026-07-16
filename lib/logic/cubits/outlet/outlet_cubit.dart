import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/data/models/outlet.dart';
import 'package:flutter_laundry_offline_app/data/repositories/outlet_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/outlet/outlet_state.dart';

class OutletCubit extends Cubit<OutletState> {
  final OutletRepository _repository;

  OutletCubit({OutletRepository? repository})
      : _repository = repository ?? OutletRepository(),
        super(OutletInitial());

  Outlet? _currentOutlet;
  List<Outlet> _outlets = [];

  Outlet? get currentOutlet => _currentOutlet;
  List<Outlet> get outlets => _outlets;

  /// Load all outlets and current outlet
  Future<void> loadOutlets() async {
    emit(OutletLoading());

    try {
      _outlets = await _repository.getAllOutlets();
      _currentOutlet = await _repository.getCurrentOutlet();

      // If no current outlet is set but outlets exist, set the first one
      if (_currentOutlet == null && _outlets.isNotEmpty) {
        _currentOutlet = _outlets.first;
        await _repository.setCurrentOutletId(_currentOutlet!.id!);
        // Also update OutletService
        await OutletService.instance.setCurrentOutlet(_currentOutlet!.id!);
      }

      emit(OutletLoaded(
        outlets: _outlets,
        currentOutlet: _currentOutlet,
      ));
    } catch (e, stack) {
      debugPrint('OutletCubit.loadOutlets error: $e\n$stack');
      emit(OutletError(message: 'Gagal memuat outlet: ${e.toString()}'));
    }
  }

  /// Switch to another outlet
  Future<void> switchOutlet(Outlet outlet) async {
    if (outlet.id == null) {
      emit(const OutletError(message: 'Outlet tidak valid'));
      return;
    }

    emit(OutletSwitching());

    try {
      await _repository.setCurrentOutletId(outlet.id!);
      _currentOutlet = outlet;

      // Update OutletService so repositories use the new outlet
      await OutletService.instance.setCurrentOutlet(outlet.id!);

      emit(OutletSwitched(
        outlet: outlet,
        message: 'Berhasil beralih ke ${outlet.name}',
      ));

      // Reload to update state
      await loadOutlets();
    } catch (e) {
      emit(OutletError(message: 'Gagal beralih outlet: ${e.toString()}'));
    }
  }

  /// Create new outlet
  Future<void> createOutlet({
    required String name,
    String? address,
    String? phone,
    String invoicePrefix = 'INV',
  }) async {
    if (name.trim().isEmpty) {
      emit(const OutletError(message: 'Nama outlet tidak boleh kosong'));
      return;
    }

    emit(OutletCreating());

    try {
      final newOutlet = await _repository.createOutlet(Outlet(
        name: name.trim(),
        address: address?.trim(),
        phone: phone?.trim(),
        invoicePrefix: invoicePrefix.trim().toUpperCase(),
      ));

      _outlets.insert(0, newOutlet);

      emit(OutletCreated(
        outlet: newOutlet,
        message: 'Outlet ${newOutlet.name} berhasil dibuat',
      ));

      // Reload to update state
      await loadOutlets();
    } catch (e) {
      emit(OutletError(message: 'Gagal membuat outlet: ${e.toString()}'));
    }
  }

  /// Update outlet
  Future<void> updateOutlet(Outlet outlet) async {
    if (outlet.id == null) {
      emit(const OutletError(message: 'Outlet tidak valid'));
      return;
    }

    if (outlet.name.trim().isEmpty) {
      emit(const OutletError(message: 'Nama outlet tidak boleh kosong'));
      return;
    }

    emit(OutletUpdating());

    try {
      final updatedOutlet = await _repository.updateOutlet(outlet);

      // Update in local list
      final index = _outlets.indexWhere((o) => o.id == outlet.id);
      if (index >= 0) {
        _outlets[index] = updatedOutlet;
      }

      // Update current outlet if this is the current one
      if (_currentOutlet?.id == outlet.id) {
        _currentOutlet = updatedOutlet;
        // IMPORTANT: Reload OutletService to get updated data (e.g., invoice prefix)
        await OutletService.instance.loadCurrentOutlet();
      }

      emit(OutletUpdated(
        outlet: updatedOutlet,
        message: 'Outlet berhasil diperbarui',
      ));

      // Reload to update state
      await loadOutlets();
    } catch (e) {
      emit(OutletError(message: 'Gagal memperbarui outlet: ${e.toString()}'));
    }
  }

  /// Delete outlet (only if not the current one and there are more than 1 outlet)
  Future<void> deleteOutlet(int outletId) async {
    if (_currentOutlet?.id == outletId) {
      emit(const OutletError(
          message: 'Tidak dapat menghapus outlet yang sedang aktif'));
      return;
    }

    if (_outlets.length <= 1) {
      emit(const OutletError(
          message: 'Tidak dapat menghapus outlet terakhir'));
      return;
    }

    emit(OutletLoading());

    try {
      await _repository.deleteOutlet(outletId);
      _outlets.removeWhere((o) => o.id == outletId);

      emit(OutletLoaded(
        outlets: _outlets,
        currentOutlet: _currentOutlet,
      ));
    } catch (e) {
      emit(OutletError(message: 'Gagal menghapus outlet: ${e.toString()}'));
    }
  }

  /// Get current outlet id (sync method for other repositories)
  int? getCurrentOutletIdSync() {
    return _currentOutlet?.id;
  }

  /// Get current outlet's remote id for Supabase
  String? getCurrentOutletRemoteId() {
    return _currentOutlet?.remoteId;
  }
}
