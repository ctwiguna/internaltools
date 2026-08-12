import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/services/sync_service.dart';
import 'package:flutter_laundry_offline_app/data/models/cancellation_request.dart';
import 'package:flutter_laundry_offline_app/data/models/order.dart';
import 'package:flutter_laundry_offline_app/data/models/user.dart';
import 'package:flutter_laundry_offline_app/data/repositories/cancellation_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/hybrid_order_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_cancellation_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/cancellation/cancellation_state.dart';

class CancellationCubit extends Cubit<CancellationState> {
  static const _uuidGen = Uuid();

  final CancellationRepository _localRepo;
  final SupabaseCancellationRepository _onlineRepo;
  final HybridOrderRepository _orderRepository;
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;

  CancellationCubit({
    CancellationRepository? localRepo,
    SupabaseCancellationRepository? onlineRepo,
    HybridOrderRepository? orderRepository,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
  })  : _localRepo = localRepo ?? CancellationRepository(),
        _onlineRepo = onlineRepo ?? SupabaseCancellationRepository(),
        _orderRepository = orderRepository ?? HybridOrderRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance,
        super(const CancellationInitial());

  bool get _isOnline => _connectivity.isOnline && _supabase.isAuthenticated;

  Map<String, dynamic> _buildSnapshot(Order order) {
    return {
      'order': order.toMap(),
      'items': order.items?.map((i) => i.toMap()).toList() ?? [],
      'payments': order.payments?.map((p) => p.toMap()).toList() ?? [],
    };
  }

  /// Ajukan pembatalan untuk [order]. Order dengan status `done` tidak
  /// boleh diajukan (divalidasi juga di sini, bukan cuma di UI).
  Future<void> requestCancellation({
    required Order order,
    required String reason,
    required User requester,
  }) async {
    emit(const CancellationLoading());

    if (order.status == OrderStatus.done) {
      emit(const CancellationError(
        'Order yang sudah Selesai tidak bisa diajukan pembatalan',
      ));
      return;
    }
    if (reason.trim().isEmpty) {
      emit(const CancellationError('Alasan pembatalan harus diisi'));
      return;
    }

    try {
      final snapshot = _buildSnapshot(order);

      if (order.isRemote) {
        await _onlineRepo.create(
          orderRemoteId: order.remoteId!,
          invoiceNo: order.invoiceNo,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          totalPrice: order.totalPrice,
          paid: order.paid,
          orderSnapshot: snapshot,
          reason: reason.trim(),
          requestedByName: requester.name,
        );
      } else {
        final uuid = _uuidGen.v4();
        final outletIdStr = OutletService.instance.currentOutletIdStr;
        final request = CancellationRequest(
          uuid: uuid,
          outletId: outletIdStr,
          orderLocalId: order.id,
          invoiceNo: order.invoiceNo,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          totalPrice: order.totalPrice,
          paid: order.paid,
          orderSnapshot: snapshot,
          reason: reason.trim(),
          requestedBy: requester.id,
          requestedByRemoteId: requester.remoteId,
          requestedByName: requester.name,
          createdAt: DateTime.now(),
        );
        final localId = await _localRepo.insert(request);

        await SyncService.instance.queueForSync(
          table: 'order_cancellation_requests',
          localId: localId,
          action: SyncAction.insert,
          data: {
            'id': uuid,
            'local_outlet_id': outletIdStr,
            'order_id': order.remoteId,
            'invoice_no': order.invoiceNo,
            'customer_name': order.customerName,
            'customer_phone': order.customerPhone,
            'total_price': order.totalPrice,
            'paid': order.paid,
            'order_snapshot': snapshot,
            'reason': reason.trim(),
            'status': CancellationStatus.pending.value,
            'requested_by': requester.remoteId,
            'requested_by_name': requester.name,
          },
        );
      }

      emit(const CancellationRequestSuccess(
        'Pengajuan pembatalan berhasil dikirim, menunggu persetujuan owner',
      ));
    } catch (e) {
      emit(CancellationError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Cek apakah [orderId] (int lokal atau String UUID remote) punya
  /// pengajuan pembatalan yang masih pending. Dipanggil imperatif dari
  /// layar detail order, bukan lewat state.
  Future<CancellationRequest?> checkPendingForOrder(dynamic orderId) async {
    try {
      if (orderId is String) {
        return await _onlineRepo.getPendingForOrder(orderId);
      }
      if (orderId is int) {
        return await _localRepo.getPendingForOrder(orderId);
      }
    } catch (_) {
      // Abaikan error cek pending — anggap tidak ada yang pending
    }
    return null;
  }

  /// Muat daftar pengajuan pembatalan outlet aktif.
  /// [onlyMine]: kasir cuma lihat pengajuan miliknya sendiri.
  Future<void> loadRequests({
    CancellationStatus? status,
    bool onlyMine = false,
    User? currentUser,
  }) async {
    emit(const CancellationLoading());
    try {
      List<CancellationRequest> requests;
      if (_isOnline) {
        final requestedByRemoteId =
            onlyMine ? _supabase.client.auth.currentUser?.id : null;
        requests = await _onlineRepo.getByOutlet(
          status: status,
          requestedByRemoteId: requestedByRemoteId,
        );
      } else {
        requests = await _localRepo.getByOutlet(
          status: status,
          requestedBy: onlyMine ? currentUser?.id : null,
        );
      }
      emit(CancellationLoaded(requests, filterStatus: status));
    } catch (e) {
      emit(CancellationError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Setujui pengajuan: hapus order asli + tandai request disetujui.
  Future<void> approve(CancellationRequest request, {required User reviewer}) async {
    emit(const CancellationLoading());
    try {
      final orderIdentifier = request.orderRemoteId ?? request.orderLocalId;
      if (orderIdentifier != null) {
        await _orderRepository.deleteOrder(orderIdentifier);
      }
      await _review(
        request,
        status: CancellationStatus.approved,
        reviewer: reviewer,
      );
      emit(const CancellationReviewSuccess('Order berhasil dibatalkan'));
    } catch (e) {
      emit(CancellationError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Tolak pengajuan: order tetap aktif seperti semula.
  Future<void> reject(
    CancellationRequest request, {
    required User reviewer,
    String? note,
  }) async {
    emit(const CancellationLoading());
    try {
      await _review(
        request,
        status: CancellationStatus.rejected,
        reviewer: reviewer,
        note: note,
      );
      emit(const CancellationReviewSuccess('Pengajuan pembatalan ditolak'));
    } catch (e) {
      emit(CancellationError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _review(
    CancellationRequest request, {
    required CancellationStatus status,
    required User reviewer,
    String? note,
  }) async {
    if (_isOnline) {
      await _onlineRepo.review(
        request.uuid,
        status: status,
        reviewedByName: reviewer.name,
        reviewNote: note,
      );
    } else {
      await _localRepo.updateReview(
        request.uuid,
        status: status,
        reviewedBy: reviewer.id,
        reviewedByRemoteId: reviewer.remoteId,
        reviewedByName: reviewer.name,
        reviewNote: note,
      );

      final updated = await _localRepo.getByUuid(request.uuid);
      if (updated != null) {
        final outletIdStr = OutletService.instance.currentOutletIdStr;
        await SyncService.instance.queueForSync(
          table: 'order_cancellation_requests',
          localId: updated.id!,
          action: SyncAction.insert,
          data: {
            'id': updated.uuid,
            'local_outlet_id': outletIdStr,
            'order_id': updated.orderRemoteId,
            'invoice_no': updated.invoiceNo,
            'customer_name': updated.customerName,
            'customer_phone': updated.customerPhone,
            'total_price': updated.totalPrice,
            'paid': updated.paid,
            'order_snapshot': updated.orderSnapshot,
            'reason': updated.reason,
            'status': updated.status.value,
            'requested_by': updated.requestedByRemoteId,
            'requested_by_name': updated.requestedByName,
            'reviewed_by': updated.reviewedByRemoteId,
            'reviewed_by_name': updated.reviewedByName,
            'review_note': updated.reviewNote,
            'reviewed_at': updated.reviewedAt?.toIso8601String(),
          },
        );
      }
    }
  }
}
