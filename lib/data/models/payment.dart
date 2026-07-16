import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

enum PaymentMethod { cash, transfer, qris }

extension PaymentMethodExtension on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.transfer:
        return 'transfer';
      case PaymentMethod.qris:
        return 'qris';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.transfer:
        return 'Transfer';
      case PaymentMethod.qris:
        return 'QRIS';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'transfer':
        return PaymentMethod.transfer;
      case 'qris':
        return PaymentMethod.qris;
      default:
        return PaymentMethod.cash;
    }
  }
}

class Payment extends Equatable {
  final int? id;
  final String? remoteId; // Supabase UUID
  final int? orderId; // Local order ID
  final String? orderRemoteId; // Supabase order UUID
  final int amount;
  final int change; // Kembalian
  final DateTime paymentDate;
  final PaymentMethod paymentMethod;
  final String? notes;
  final int? receivedBy; // Local user ID
  final String? receivedByRemoteId; // Supabase user UUID
  final DateTime? createdAt;

  const Payment({
    this.id,
    this.remoteId,
    this.orderId,
    this.orderRemoteId,
    required this.amount,
    this.change = 0,
    required this.paymentDate,
    required this.paymentMethod,
    this.notes,
    this.receivedBy,
    this.receivedByRemoteId,
    this.createdAt,
  });

  /// Check if this is a remote (Supabase) payment
  bool get isRemote => remoteId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'order_id': orderId,
      'order_remote_id': orderRemoteId,
      'amount': amount,
      'change': change,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod.value,
      'notes': notes,
      'received_by': receivedBy,
      'received_by_remote_id': receivedByRemoteId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Convert to Supabase-compatible map (excludes local id)
  Map<String, dynamic> toSupabaseMap() {
    return {
      if (remoteId != null) 'id': remoteId,
      'order_id': orderRemoteId,
      'amount': amount,
      'change_amount': change,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod.value,
      'notes': notes,
      'received_by': receivedByRemoteId,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: TypeHelper.asNullableInt(map['id']),
      remoteId: TypeHelper.asNullableString(map['remote_id']),
      orderId: TypeHelper.asNullableInt(map['order_id']),
      orderRemoteId: TypeHelper.asNullableString(map['order_remote_id']),
      amount: TypeHelper.asInt(map['amount']),
      change: TypeHelper.asInt(map['change']),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      paymentMethod:
          PaymentMethodExtension.fromString(map['payment_method'] as String),
      notes: TypeHelper.asNullableString(map['notes']),
      receivedBy: TypeHelper.asNullableInt(map['received_by']),
      receivedByRemoteId: TypeHelper.asNullableString(map['received_by_remote_id']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Create from Supabase response
  factory Payment.fromSupabase(Map<String, dynamic> map) {
    return Payment(
      remoteId: TypeHelper.asNullableString(map['id']),
      orderRemoteId: TypeHelper.asNullableString(map['order_id']),
      amount: TypeHelper.asInt(map['amount']),
      change: TypeHelper.asInt(map['change_amount']),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      paymentMethod:
          PaymentMethodExtension.fromString(map['payment_method'] as String),
      notes: TypeHelper.asNullableString(map['notes']),
      receivedByRemoteId: TypeHelper.asNullableString(map['received_by']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Payment copyWith({
    int? id,
    String? remoteId,
    int? orderId,
    String? orderRemoteId,
    int? amount,
    int? change,
    DateTime? paymentDate,
    PaymentMethod? paymentMethod,
    String? notes,
    int? receivedBy,
    String? receivedByRemoteId,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      orderId: orderId ?? this.orderId,
      orderRemoteId: orderRemoteId ?? this.orderRemoteId,
      amount: amount ?? this.amount,
      change: change ?? this.change,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      receivedBy: receivedBy ?? this.receivedBy,
      receivedByRemoteId: receivedByRemoteId ?? this.receivedByRemoteId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        remoteId,
        orderId,
        orderRemoteId,
        amount,
        change,
        paymentDate,
        paymentMethod,
        notes,
        receivedBy,
        receivedByRemoteId,
        createdAt,
      ];
}
