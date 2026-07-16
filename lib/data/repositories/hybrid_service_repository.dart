import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/service.dart';
import 'package:flutter_laundry_offline_app/data/repositories/service_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_service_repository.dart';

/// Hybrid repository that automatically switches between offline and online data sources
class HybridServiceRepository {
  final ServiceRepository _offlineRepo;
  final SupabaseServiceRepository _onlineRepo;
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;

  /// Current outlet ID for online operations
  String? _outletId;

  HybridServiceRepository({
    ServiceRepository? offlineRepo,
    SupabaseServiceRepository? onlineRepo,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
  })  : _offlineRepo = offlineRepo ?? ServiceRepository(),
        _onlineRepo = onlineRepo ?? SupabaseServiceRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance;

  /// Set the outlet ID for online operations
  void setOutletId(String? outletId) {
    _outletId = outletId;
  }

  /// Check if should use online mode
  bool get _shouldUseOnline =>
      _connectivity.isOnline && _supabase.isAuthenticated && _outletId != null;

  /// Get all active services
  Future<List<Service>> getAllServices() async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getAllServices();
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getAllServices();
  }

  /// Get all services (including inactive)
  Future<List<Service>> getAllServicesIncludingInactive() async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getAllServicesIncludingInactive();
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getAllServicesIncludingInactive();
  }

  /// Get service by ID (supports both local int ID and remote UUID)
  Future<Service?> getServiceById(dynamic id) async {
    if (id is String && _shouldUseOnline) {
      try {
        return await _onlineRepo.getServiceById(id);
      } catch (_) {
        // Fallback to offline
      }
    }
    if (id is int) {
      return await _offlineRepo.getServiceById(id);
    }
    return null;
  }

  /// Create new service
  Future<Service> createService(Service service) async {
    if (_shouldUseOnline && _outletId != null) {
      try {
        return await _onlineRepo.createService(
          service.copyWith(outletId: _outletId),
        );
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.createService(service);
  }

  /// Update service
  Future<Service> updateService(Service service) async {
    if (_shouldUseOnline && service.remoteId != null) {
      try {
        return await _onlineRepo.updateService(service);
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.updateService(service);
  }

  /// Delete service (soft delete)
  Future<void> deleteService(dynamic id) async {
    if (id is String && _shouldUseOnline) {
      try {
        await _onlineRepo.deleteService(id);
        return;
      } catch (_) {
        // Cannot fallback delete to offline for remote service
        rethrow;
      }
    }
    if (id is int) {
      await _offlineRepo.deleteService(id);
    }
  }

  /// Restore deleted service
  Future<void> restoreService(dynamic id) async {
    if (id is String && _shouldUseOnline) {
      try {
        await _onlineRepo.restoreService(id);
        return;
      } catch (_) {
        // Cannot fallback restore to offline for remote service
        rethrow;
      }
    }
    if (id is int) {
      await _offlineRepo.restoreService(id);
    }
  }

  /// Check if service name exists
  Future<bool> serviceNameExists(String name, {dynamic excludeId}) async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.serviceNameExists(
          name,
          excludeId: excludeId is String ? excludeId : null,
        );
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.serviceNameExists(
      name,
      excludeId: excludeId is int ? excludeId : null,
    );
  }

  /// Get service count
  Future<int> getServiceCount() async {
    // Always use offline for count (faster)
    return await _offlineRepo.getServiceCount();
  }
}
