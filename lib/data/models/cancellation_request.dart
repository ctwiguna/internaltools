import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

enum CancellationStatus { pending, approved, rejected }

extension CancellationStatusExtension on CancellationStatus {
  String get value {
    switch (this) {
      case CancellationStatus.pending:
        return 'pending';
      case CancellationStatus.approved:
        return 'approved';
      case CancellationStatus.rejected:
        return 'rejected';
    }
  }

  /// Label yang ditampilkan ke user. Request yang di-approve artinya order
  /// aslinya sudah dihapus, jadi labelnya "Dibatalkan" (bukan "Disetujui").
  String get displayName {
    switch (this) {
      case CancellationStatus.pending:
        return 'Menunggu Persetujuan';
      case CancellationStatus.approved:
        return 'Dibatalkan';
      case CancellationStatus.rejected:
        return 'Ditolak';
    }
  }

  static CancellationStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return CancellationStatus.pending;
      case 'approved':
        return CancellationStatus.approved;
      case 'rejected':
        return CancellationStatus.rejected;
      default:
        return CancellationStatus.pending;
    }
  }
}

/// Pengajuan pembatalan order oleh kasir yang direview oleh owner.
/// `orderSnapshot` menyimpan salinan lengkap order (customer, item, payment)
/// pada saat pengajuan dibuat — ini menjadi satu-satunya jejak order
/// setelah order aslinya dihapus saat request di-approve.
class CancellationRequest extends Equatable {
  final int? id;
  final String uuid; // juga dipakai sebagai primary key di Supabase
  final String? outletId;
  final int? orderLocalId;
  final String? orderRemoteId;
  final String invoiceNo;
  final String customerName;
  final String? customerPhone;
  final int totalPrice;
  final int paid;
  final Map<String, dynamic> orderSnapshot;
  final String reason;
  final CancellationStatus status;
  final int? requestedBy;
  final String? requestedByRemoteId;
  final String requestedByName;
  final int? reviewedBy;
  final String? reviewedByRemoteId;
  final String? reviewedByName;
  final String? reviewNote;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const CancellationRequest({
    this.id,
    required this.uuid,
    this.outletId,
    this.orderLocalId,
    this.orderRemoteId,
    required this.invoiceNo,
    required this.customerName,
    this.customerPhone,
    required this.totalPrice,
    this.paid = 0,
    required this.orderSnapshot,
    required this.reason,
    this.status = CancellationStatus.pending,
    this.requestedBy,
    this.requestedByRemoteId,
    required this.requestedByName,
    this.reviewedBy,
    this.reviewedByRemoteId,
    this.reviewedByName,
    this.reviewNote,
    this.createdAt,
    this.reviewedAt,
  });

  bool get isPending => status == CancellationStatus.pending;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'outlet_id': outletId,
      'order_local_id': orderLocalId,
      'order_remote_id': orderRemoteId,
      'invoice_no': invoiceNo,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_price': totalPrice,
      'paid': paid,
      'order_snapshot': json.encode(orderSnapshot),
      'reason': reason,
      'status': status.value,
      'requested_by': requestedBy,
      'requested_by_remote_id': requestedByRemoteId,
      'requested_by_name': requestedByName,
      'reviewed_by': reviewedBy,
      'reviewed_by_remote_id': reviewedByRemoteId,
      'reviewed_by_name': reviewedByName,
      'review_note': reviewNote,
      'created_at': createdAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  /// Payload upsert ke Supabase — `id` client-generated (pola sama seperti
  /// attendance/shifts), bukan `remote_id` terpisah.
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': uuid,
      'outlet_id': outletId,
      'order_id': orderRemoteId,
      'invoice_no': invoiceNo,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_price': totalPrice,
      'paid': paid,
      'order_snapshot': orderSnapshot,
      'reason': reason,
      'status': status.value,
      'requested_by': requestedByRemoteId,
      'requested_by_name': requestedByName,
      'reviewed_by': reviewedByRemoteId,
      'reviewed_by_name': reviewedByName,
      'review_note': reviewNote,
      'created_at': createdAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  static Map<String, dynamic> _decodeSnapshot(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      return json.decode(raw) as Map<String, dynamic>;
    }
    return {};
  }

  factory CancellationRequest.fromMap(Map<String, dynamic> map) {
    return CancellationRequest(
      id: TypeHelper.asNullableInt(map['id']),
      uuid: map['uuid'] as String,
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      orderLocalId: TypeHelper.asNullableInt(map['order_local_id']),
      orderRemoteId: TypeHelper.asNullableString(map['order_remote_id']),
      invoiceNo: map['invoice_no'] as String,
      customerName: map['customer_name'] as String,
      customerPhone: TypeHelper.asNullableString(map['customer_phone']),
      totalPrice: TypeHelper.asInt(map['total_price']),
      paid: TypeHelper.asInt(map['paid']),
      orderSnapshot: _decodeSnapshot(map['order_snapshot']),
      reason: TypeHelper.asNullableString(map['reason']) ?? '',
      status: CancellationStatusExtension.fromString(map['status'] as String),
      requestedBy: TypeHelper.asNullableInt(map['requested_by']),
      requestedByRemoteId:
          TypeHelper.asNullableString(map['requested_by_remote_id']),
      requestedByName: map['requested_by_name'] as String,
      reviewedBy: TypeHelper.asNullableInt(map['reviewed_by']),
      reviewedByRemoteId:
          TypeHelper.asNullableString(map['reviewed_by_remote_id']),
      reviewedByName: TypeHelper.asNullableString(map['reviewed_by_name']),
      reviewNote: TypeHelper.asNullableString(map['review_note']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
    );
  }

  factory CancellationRequest.fromSupabase(Map<String, dynamic> map) {
    return CancellationRequest(
      uuid: map['id'] as String,
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      orderRemoteId: TypeHelper.asNullableString(map['order_id']),
      invoiceNo: map['invoice_no'] as String,
      customerName: map['customer_name'] as String,
      customerPhone: TypeHelper.asNullableString(map['customer_phone']),
      totalPrice: TypeHelper.asInt(map['total_price']),
      paid: TypeHelper.asInt(map['paid']),
      orderSnapshot: _decodeSnapshot(map['order_snapshot']),
      reason: TypeHelper.asNullableString(map['reason']) ?? '',
      status: CancellationStatusExtension.fromString(map['status'] as String),
      requestedByRemoteId: TypeHelper.asNullableString(map['requested_by']),
      requestedByName: map['requested_by_name'] as String,
      reviewedByRemoteId: TypeHelper.asNullableString(map['reviewed_by']),
      reviewedByName: TypeHelper.asNullableString(map['reviewed_by_name']),
      reviewNote: TypeHelper.asNullableString(map['review_note']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
    );
  }

  CancellationRequest copyWith({
    int? id,
    String? uuid,
    String? outletId,
    int? orderLocalId,
    String? orderRemoteId,
    String? invoiceNo,
    String? customerName,
    String? customerPhone,
    int? totalPrice,
    int? paid,
    Map<String, dynamic>? orderSnapshot,
    String? reason,
    CancellationStatus? status,
    int? requestedBy,
    String? requestedByRemoteId,
    String? requestedByName,
    int? reviewedBy,
    String? reviewedByRemoteId,
    String? reviewedByName,
    String? reviewNote,
    DateTime? createdAt,
    DateTime? reviewedAt,
  }) {
    return CancellationRequest(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      outletId: outletId ?? this.outletId,
      orderLocalId: orderLocalId ?? this.orderLocalId,
      orderRemoteId: orderRemoteId ?? this.orderRemoteId,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      totalPrice: totalPrice ?? this.totalPrice,
      paid: paid ?? this.paid,
      orderSnapshot: orderSnapshot ?? this.orderSnapshot,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedByRemoteId: requestedByRemoteId ?? this.requestedByRemoteId,
      requestedByName: requestedByName ?? this.requestedByName,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByRemoteId: reviewedByRemoteId ?? this.reviewedByRemoteId,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewNote: reviewNote ?? this.reviewNote,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        outletId,
        orderLocalId,
        orderRemoteId,
        invoiceNo,
        customerName,
        customerPhone,
        totalPrice,
        paid,
        reason,
        status,
        requestedBy,
        requestedByRemoteId,
        requestedByName,
        reviewedBy,
        reviewedByRemoteId,
        reviewedByName,
        reviewNote,
        createdAt,
        reviewedAt,
      ];
}
