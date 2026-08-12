import 'package:uuid/uuid.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/cancellation_request.dart';

/// Repository pengajuan pembatalan order dari Supabase.
/// Semua query terfilter outlet aktif (OutletService.currentOutletUuid),
/// mengikuti pola SupabaseOrderRepository/SupabaseAttendanceRepository.
class SupabaseCancellationRepository {
  static const _uuidGen = Uuid();

  final SupabaseService _supabase;

  SupabaseCancellationRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  String? get _outletUuid => OutletService.instance.currentOutletUuid;

  Future<List<CancellationRequest>> getByOutlet({
    CancellationStatus? status,
    String? requestedByRemoteId,
  }) async {
    var query = _supabase.client.from('order_cancellation_requests').select();

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);
    if (status != null) query = query.eq('status', status.value);
    if (requestedByRemoteId != null) {
      query = query.eq('requested_by', requestedByRemoteId);
    }

    final data = await query.order('created_at', ascending: false);

    return (data as List)
        .map((map) =>
            CancellationRequest.fromSupabase(map as Map<String, dynamic>))
        .toList();
  }

  Future<CancellationRequest?> getPendingForOrder(String orderRemoteId) async {
    final data = await _supabase.client
        .from('order_cancellation_requests')
        .select()
        .eq('order_id', orderRemoteId)
        .eq('status', CancellationStatus.pending.value)
        .order('created_at', ascending: false)
        .limit(1);

    if ((data as List).isEmpty) return null;
    return CancellationRequest.fromSupabase(data.first);
  }

  /// Ajukan pembatalan. Mengembalikan uuid request yang dibuat.
  Future<String> create({
    required String orderRemoteId,
    required String invoiceNo,
    required String customerName,
    String? customerPhone,
    required int totalPrice,
    required int paid,
    required Map<String, dynamic> orderSnapshot,
    required String reason,
    required String requestedByName,
  }) async {
    final outletUuid = _outletUuid;
    if (outletUuid == null) {
      throw Exception('Outlet aktif belum dipilih');
    }

    final uuid = _uuidGen.v4();
    final authUserId = _supabase.client.auth.currentUser?.id;

    await _supabase.client.from('order_cancellation_requests').insert({
      'id': uuid,
      'outlet_id': outletUuid,
      'order_id': orderRemoteId,
      'invoice_no': invoiceNo,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_price': totalPrice,
      'paid': paid,
      'order_snapshot': orderSnapshot,
      'reason': reason,
      'status': CancellationStatus.pending.value,
      'requested_by': authUserId,
      'requested_by_name': requestedByName,
    });

    return uuid;
  }

  Future<void> review(
    String uuid, {
    required CancellationStatus status,
    required String reviewedByName,
    String? reviewNote,
  }) async {
    final authUserId = _supabase.client.auth.currentUser?.id;

    await _supabase.client.from('order_cancellation_requests').update({
      'status': status.value,
      'reviewed_by': authUserId,
      'reviewed_by_name': reviewedByName,
      'review_note': reviewNote,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', uuid);
  }
}
