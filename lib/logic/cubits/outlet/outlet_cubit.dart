import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/outlet.dart';
import 'package:flutter_laundry_offline_app/data/repositories/outlet_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_outlet_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/outlet/outlet_state.dart';

class OutletCubit extends Cubit<OutletState> {
  final OutletRepository _repository;
  final SupabaseOutletRepository _remoteRepository;
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;

  OutletCubit({
    OutletRepository? repository,
    SupabaseOutletRepository? remoteRepository,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
  })  : _repository = repository ?? OutletRepository(),
        _remoteRepository = remoteRepository ?? SupabaseOutletRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance,
        super(OutletInitial());

  Outlet? _currentOutlet;
  List<Outlet> _outlets = [];

  Outlet? get currentOutlet => _currentOutlet;
  List<Outlet> get outlets => _outlets;

  /// Mode online aktif jika ada koneksi DAN user login Supabase
  bool get _isOnline => _connectivity.isOnline && _supabase.isAuthenticated;

  /// Load all outlets and current outlet
  Future<void> loadOutlets() async {
    emit(OutletLoading());

    // Mode online: ambil daftar outlet langsung dari Supabase
    if (_isOnline) {
      try {
        _outlets = await _remoteRepository.getOutlets();

        // Tentukan outlet aktif dari konteks OutletService (UUID)
        final uuid = OutletService.instance.currentOutletUuid;
        Outlet? current;
        if (uuid != null) {
          for (final o in _outlets) {
            if (o.remoteId == uuid) {
              current = o;
              break;
            }
          }
        }
        current ??= _outlets.isNotEmpty ? _outlets.first : null;
        _currentOutlet = current;

        // Pastikan konteks OutletService selalu valid & tersimpan
        if (current != null && current.remoteId != null) {
          await OutletService.instance
              .setCurrentOutletRemote(current.remoteId!, outlet: current);
        }

        emit(OutletLoaded(
          outlets: _outlets,
          currentOutlet: _currentOutlet,
        ));
        return;
      } catch (e) {
        debugPrint('OutletCubit.loadOutlets online error: $e');
        // Lanjut fallback ke lokal di bawah
      }
    }

    // Mode offline/lokal (fallback)
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
    emit(OutletSwitching());

    // Mode online: switch berbasis UUID Supabase
    if (_isOnline && outlet.remoteId != null) {
      try {
        await OutletService.instance
            .setCurrentOutletRemote(outlet.remoteId!, outlet: outlet);
        _currentOutlet = outlet;

        emit(OutletSwitched(
          outlet: outlet,
          message: 'Berhasil beralih ke ${outlet.name}',
        ));

        // Reload to update state
        await loadOutlets();
        return;
      } catch (e) {
        emit(OutletError(message: 'Gagal beralih outlet: ${e.toString()}'));
        return;
      }
    }

    // Mode lokal (legacy)
    if (outlet.id == null) {
      emit(const OutletError(message: 'Outlet tidak valid'));
      return;
    }

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
      final draft = Outlet(
        name: name.trim(),
        address: address?.trim(),
        phone: phone?.trim(),
        invoicePrefix: invoicePrefix.trim().toUpperCase(),
      );

      final newOutlet = _isOnline
          ? await _remoteRepository.createOutlet(draft)
          : await _repository.createOutlet(draft);

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
    if (outlet.name.trim().isEmpty) {
      emit(const OutletError(message: 'Nama outlet tidak boleh kosong'));
      return;
    }

    emit(OutletUpdating());

    try {
      final Outlet updatedOutlet;
      if (_isOnline && outlet.remoteId != null) {
        updatedOutlet = await _remoteRepository.updateOutlet(outlet);
      } else {
        updatedOutlet = await _repository.updateOutlet(outlet);
      }

      // Update in local list
      final index = _outlets.indexWhere((o) =>
          (o.remoteId != null && o.remoteId == updatedOutlet.remoteId) ||
          (o.id != null && o.id == updatedOutlet.id));
      if (index >= 0) {
        _outlets[index] = updatedOutlet;
      }

      // Update current outlet if this is the current one
      final isCurrent = (_currentOutlet?.remoteId != null &&
              _currentOutlet?.remoteId == updatedOutlet.remoteId) ||
          (_currentOutlet?.id != null &&
              _currentOutlet?.id == updatedOutlet.id);
      if (isCurrent) {
        _currentOutlet = updatedOutlet;
        // Refresh OutletService (mis. invoice prefix berubah)
        if (updatedOutlet.remoteId != null) {
          await OutletService.instance.setCurrentOutletRemote(
            updatedOutlet.remoteId!,
            outlet: updatedOutlet,
          );
        } else {
          await OutletService.instance.loadCurrentOutlet();
        }
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

  /// Delete outlet (menerima int id lokal atau String UUID remote).
  /// Tidak bisa menghapus outlet yang sedang aktif / outlet terakhir.
  Future<void> deleteOutlet(dynamic outletId) async {
    final isCurrent =
        (outletId is String && outletId == _currentOutlet?.remoteId) ||
            (outletId is int && outletId == _currentOutlet?.id);
    if (isCurrent) {
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
      if (outletId is String && _isOnline) {
        await _remoteRepository.deleteOutlet(outletId);
        _outlets.removeWhere((o) => o.remoteId == outletId);
      } else if (outletId is int) {
        await _repository.deleteOutlet(outletId);
        _outlets.removeWhere((o) => o.id == outletId);
      }

      emit(OutletLoaded(
        outlets: _outlets,
        currentOutlet: _currentOutlet,
      ));
    } catch (e) {
      emit(OutletError(message: 'Gagal menghapus outlet: ${e.toString()}'));
      emit(OutletLoaded(
        outlets: _outlets,
        currentOutlet: _currentOutlet,
      ));
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
