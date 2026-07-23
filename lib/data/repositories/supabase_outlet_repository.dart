import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/outlet.dart';

/// Repository for outlet data from Supabase.
///
/// RLS di sisi server sudah membatasi hasil:
/// - owner  -> semua outlet miliknya
/// - kasir  -> hanya outlet tempat dia bertugas
class SupabaseOutletRepository {
  final SupabaseService _supabase;

  SupabaseOutletRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  /// Get all outlets visible to current user
  Future<List<Outlet>> getOutlets() async {
    final data = await _supabase.client
        .from('outlets')
        .select()
        .order('created_at');

    return (data as List).map((map) => Outlet.fromSupabase(map)).toList();
  }

  /// Create new outlet (owner)
  Future<Outlet> createOutlet(Outlet outlet) async {
    final uid = _supabase.client.auth.currentUser?.id;

    final data = await _supabase.client
        .from('outlets')
        .insert({
          'name': outlet.name,
          'address': outlet.address,
          'phone': outlet.phone,
          'invoice_prefix': outlet.invoicePrefix,
          'owner_id': uid,
        })
        .select()
        .single();

    return Outlet.fromSupabase(data);
  }

  /// Update outlet
  Future<Outlet> updateOutlet(Outlet outlet) async {
    if (outlet.remoteId == null) {
      throw Exception('Outlet remote ID diperlukan untuk update');
    }

    final data = await _supabase.client
        .from('outlets')
        .update({
          'name': outlet.name,
          'address': outlet.address,
          'phone': outlet.phone,
          'invoice_prefix': outlet.invoicePrefix,
        })
        .eq('id', outlet.remoteId!)
        .select()
        .single();

    return Outlet.fromSupabase(data);
  }

  /// Delete outlet by remote UUID
  Future<void> deleteOutlet(String id) async {
    await _supabase.client.from('outlets').delete().eq('id', id);
  }
}
