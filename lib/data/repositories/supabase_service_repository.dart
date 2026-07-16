import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/service.dart';

/// Repository for service data from Supabase
class SupabaseServiceRepository {
  final SupabaseService _supabase;

  SupabaseServiceRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  /// Get all active services for current outlet
  Future<List<Service>> getAllServices() async {
    final data = await _supabase.client
        .from('services')
        .select()
        .eq('is_active', true)
        .order('name');

    return (data as List).map((map) => Service.fromSupabase(map)).toList();
  }

  /// Get all services (including inactive)
  Future<List<Service>> getAllServicesIncludingInactive() async {
    final data = await _supabase.client
        .from('services')
        .select()
        .order('is_active', ascending: false)
        .order('name');

    return (data as List).map((map) => Service.fromSupabase(map)).toList();
  }

  /// Get service by remote ID
  Future<Service?> getServiceById(String id) async {
    final data = await _supabase.client
        .from('services')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return Service.fromSupabase(data);
  }

  /// Create new service
  Future<Service> createService(Service service) async {
    if (service.name.trim().isEmpty) {
      throw Exception('Nama layanan tidak boleh kosong');
    }
    if (service.price <= 0) {
      throw Exception('Harga harus lebih dari 0');
    }

    final data = await _supabase.client
        .from('services')
        .insert(service.toSupabaseMap())
        .select()
        .single();

    return Service.fromSupabase(data);
  }

  /// Update service
  Future<Service> updateService(Service service) async {
    if (service.remoteId == null) {
      throw Exception('Service remote ID is required for update');
    }

    if (service.name.trim().isEmpty) {
      throw Exception('Nama layanan tidak boleh kosong');
    }
    if (service.price <= 0) {
      throw Exception('Harga harus lebih dari 0');
    }

    final data = await _supabase.client
        .from('services')
        .update(service.toSupabaseMap())
        .eq('id', service.remoteId!)
        .select()
        .single();

    return Service.fromSupabase(data);
  }

  /// Soft delete service (set is_active = false)
  Future<void> deleteService(String id) async {
    await _supabase.client
        .from('services')
        .update({'is_active': false})
        .eq('id', id);
  }

  /// Restore deleted service
  Future<void> restoreService(String id) async {
    await _supabase.client
        .from('services')
        .update({'is_active': true})
        .eq('id', id);
  }

  /// Check if service name exists
  Future<bool> serviceNameExists(String name, {String? excludeId}) async {
    var query = _supabase.client
        .from('services')
        .select('id')
        .ilike('name', name.trim())
        .eq('is_active', true);

    if (excludeId != null) {
      query = query.neq('id', excludeId);
    }

    final data = await query;
    return (data as List).isNotEmpty;
  }

  /// Get service count
  Future<int> getServiceCount() async {
    final data = await _supabase.client
        .from('services')
        .select('id')
        .eq('is_active', true);

    return (data as List).length;
  }
}
