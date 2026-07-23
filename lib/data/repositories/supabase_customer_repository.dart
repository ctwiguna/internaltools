import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/customer.dart';

/// Repository for customer data from Supabase
class SupabaseCustomerRepository {
  final SupabaseService _supabase;

  SupabaseCustomerRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;
  /// UUID outlet aktif (mengikuti OutletService)
  String? get _outletUuid => OutletService.instance.currentOutletUuid;
  
  Future<List<Customer>> getAllCustomers() async {
    var query = _supabase.client.from('customers').select();

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);

    final data = await query.order('name');

    return (data as List).map((map) => Customer.fromSupabase(map)).toList();
  }

  /// Get customer by remote ID
  Future<Customer?> getCustomerById(String id) async {
    final data = await _supabase.client
        .from('customers')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return Customer.fromSupabase(data);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    var supabaseQuery = _supabase.client
        .from('customers')
        .select()
        .or('name.ilike.%$query%,phone.ilike.%$query%');

    final uuid = _outletUuid;
    if (uuid != null) supabaseQuery = supabaseQuery.eq('outlet_id', uuid);

    final data = await supabaseQuery.order('name');

    return (data as List).map((map) => Customer.fromSupabase(map)).toList();
  }

  /// Create new customer
  Future<Customer> createCustomer(Customer customer) async {
    final data = await _supabase.client
        .from('customers')
        .insert(customer.toSupabaseMap())
        .select()
        .single();

    return Customer.fromSupabase(data);
  }

  /// Update customer
  Future<Customer> updateCustomer(Customer customer) async {
    if (customer.remoteId == null) {
      throw Exception('Customer remote ID is required for update');
    }

    final data = await _supabase.client
        .from('customers')
        .update(customer.toSupabaseMap())
        .eq('id', customer.remoteId!)
        .select()
        .single();

    return Customer.fromSupabase(data);
  }

  /// Delete customer
  Future<void> deleteCustomer(String id) async {
    await _supabase.client.from('customers').delete().eq('id', id);
  }

  /// Get customer by phone
  Future<Customer?> getCustomerByPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;

    final data = await _supabase.client
        .from('customers')
        .select()
        .eq('phone', cleaned)
        .maybeSingle();

    if (data == null) return null;
    return Customer.fromSupabase(data);
  }

  /// Get or create customer by phone
  Future<Customer> getOrCreateByPhone({
    required String name,
    required String phone,
    required String outletId,
  }) async {
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Check if exists
    final existing = await getCustomerByPhone(cleanedPhone);
    if (existing != null) {
      // Update name if different
      if (existing.name != name.trim()) {
        return await updateCustomer(existing.copyWith(name: name.trim()));
      }
      return existing;
    }

    // Create new
    return await createCustomer(Customer(
      name: name.trim(),
      phone: cleanedPhone,
      outletId: outletId,
    ));
  }

  /// Get top customers by total spent
  Future<List<Customer>> getTopCustomers({int limit = 10}) async {
    final data = await _supabase.client
        .from('customers')
        .select()
        .order('total_spent', ascending: false)
        .limit(limit);

    return (data as List).map((map) => Customer.fromSupabase(map)).toList();
  }

  /// Update customer order stats
  Future<void> updateCustomerStats({
    required String customerId,
    required int orderAmount,
  }) async {
    final customer = await getCustomerById(customerId);
    if (customer == null) return;

    await _supabase.client.from('customers').update({
      'total_orders': customer.totalOrders + 1,
      'total_spent': customer.totalSpent + orderAmount,
      'last_order_date': DateTime.now().toIso8601String(),
    }).eq('id', customerId);
  }
}
