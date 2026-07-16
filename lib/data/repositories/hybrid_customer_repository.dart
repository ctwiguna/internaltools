import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/customer.dart';
import 'package:flutter_laundry_offline_app/data/repositories/customer_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_customer_repository.dart';

/// Hybrid repository that automatically switches between offline and online data sources
class HybridCustomerRepository {
  final CustomerRepository _offlineRepo;
  final SupabaseCustomerRepository _onlineRepo;
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;

  /// Current outlet ID for online operations
  String? _outletId;

  HybridCustomerRepository({
    CustomerRepository? offlineRepo,
    SupabaseCustomerRepository? onlineRepo,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
  })  : _offlineRepo = offlineRepo ?? CustomerRepository(),
        _onlineRepo = onlineRepo ?? SupabaseCustomerRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance;

  /// Set the outlet ID for online operations
  void setOutletId(String? outletId) {
    _outletId = outletId;
  }

  /// Check if should use online mode
  bool get _shouldUseOnline =>
      _connectivity.isOnline && _supabase.isAuthenticated && _outletId != null;

  /// Get all customers
  Future<List<Customer>> getAllCustomers() async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getAllCustomers();
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getAllCustomers();
  }

  /// Get customer by ID (supports both local int ID and remote UUID)
  Future<Customer?> getCustomerById(dynamic id) async {
    if (id is String && _shouldUseOnline) {
      try {
        return await _onlineRepo.getCustomerById(id);
      } catch (_) {
        // Fallback to offline
      }
    }
    if (id is int) {
      return await _offlineRepo.getCustomerById(id);
    }
    return null;
  }

  /// Search customers
  Future<List<Customer>> searchCustomers(String query) async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.searchCustomers(query);
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.searchCustomers(query);
  }

  /// Create new customer
  Future<Customer> createCustomer(Customer customer) async {
    if (_shouldUseOnline && _outletId != null) {
      try {
        return await _onlineRepo.createCustomer(
          customer.copyWith(outletId: _outletId),
        );
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.createCustomer(customer);
  }

  /// Update customer
  Future<Customer> updateCustomer(Customer customer) async {
    if (_shouldUseOnline && customer.remoteId != null) {
      try {
        return await _onlineRepo.updateCustomer(customer);
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.updateCustomer(customer);
  }

  /// Delete customer
  Future<void> deleteCustomer(dynamic id) async {
    if (id is String && _shouldUseOnline) {
      try {
        await _onlineRepo.deleteCustomer(id);
        return;
      } catch (_) {
        // Cannot fallback delete to offline for remote customer
        rethrow;
      }
    }
    if (id is int) {
      await _offlineRepo.deleteCustomer(id);
    }
  }

  /// Get customer by phone
  Future<Customer?> getCustomerByPhone(String phone) async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getCustomerByPhone(phone);
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getCustomerByPhone(phone);
  }

  /// Get or create customer by phone
  Future<Customer> getOrCreateByPhone({
    required String name,
    required String phone,
  }) async {
    if (_shouldUseOnline && _outletId != null) {
      try {
        return await _onlineRepo.getOrCreateByPhone(
          name: name,
          phone: phone,
          outletId: _outletId!,
        );
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getOrCreateByPhone(name: name, phone: phone);
  }

  /// Get or create customer by name
  Future<Customer> getOrCreateByName({required String name}) async {
    // This is offline-only for now
    return await _offlineRepo.getOrCreateByName(name: name);
  }

  /// Get top customers
  Future<List<Customer>> getTopCustomers({int limit = 10}) async {
    if (_shouldUseOnline) {
      try {
        return await _onlineRepo.getTopCustomers(limit: limit);
      } catch (_) {
        // Fallback to offline
      }
    }
    return await _offlineRepo.getTopCustomers(limit: limit);
  }

  /// Update customer stats after order
  Future<void> updateCustomerStats({
    required dynamic customerId,
    required int orderAmount,
  }) async {
    if (customerId is String && _shouldUseOnline) {
      try {
        await _onlineRepo.updateCustomerStats(
          customerId: customerId,
          orderAmount: orderAmount,
        );
        return;
      } catch (_) {
        // Ignore errors
      }
    }
    if (customerId is int) {
      await _offlineRepo.updateCustomerStats(
        customerId: customerId,
        orderAmount: orderAmount,
      );
    }
  }

  /// Get customer count
  Future<int> getCustomerCount() async {
    // Always use offline for count (faster)
    return await _offlineRepo.getCustomerCount();
  }
}
