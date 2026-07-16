import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

class OrderItem extends Equatable {
  final int? id;
  final String? remoteId; // Supabase UUID
  final int? orderId; // Local order ID
  final String? orderRemoteId; // Supabase order UUID
  final int? serviceId; // Local service ID
  final String? serviceRemoteId; // Supabase service UUID
  final String serviceName;
  final double quantity;
  final String unit;
  final int pricePerUnit;
  final int subtotal;
  final DateTime? createdAt;

  const OrderItem({
    this.id,
    this.remoteId,
    this.orderId,
    this.orderRemoteId,
    this.serviceId,
    this.serviceRemoteId,
    required this.serviceName,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.subtotal,
    this.createdAt,
  });

  /// Check if this is a remote (Supabase) order item
  bool get isRemote => remoteId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'order_id': orderId,
      'order_remote_id': orderRemoteId,
      'service_id': serviceId,
      'service_remote_id': serviceRemoteId,
      'service_name': serviceName,
      'quantity': quantity,
      'unit': unit,
      'price_per_unit': pricePerUnit,
      'subtotal': subtotal,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Convert to Supabase-compatible map (excludes local id)
  Map<String, dynamic> toSupabaseMap() {
    return {
      if (remoteId != null) 'id': remoteId,
      'order_id': orderRemoteId,
      'service_id': serviceRemoteId,
      'service_name': serviceName,
      'quantity': quantity,
      'unit': unit,
      'price_per_unit': pricePerUnit,
      'subtotal': subtotal,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: TypeHelper.asNullableInt(map['id']),
      remoteId: TypeHelper.asNullableString(map['remote_id']),
      orderId: TypeHelper.asNullableInt(map['order_id']),
      orderRemoteId: TypeHelper.asNullableString(map['order_remote_id']),
      serviceId: TypeHelper.asNullableInt(map['service_id']),
      serviceRemoteId: TypeHelper.asNullableString(map['service_remote_id']),
      serviceName: map['service_name'] as String,
      quantity: TypeHelper.asDouble(map['quantity']),
      unit: map['unit'] as String,
      pricePerUnit: TypeHelper.asInt(map['price_per_unit']),
      subtotal: TypeHelper.asInt(map['subtotal']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Create from Supabase response
  factory OrderItem.fromSupabase(Map<String, dynamic> map) {
    return OrderItem(
      remoteId: TypeHelper.asNullableString(map['id']),
      orderRemoteId: TypeHelper.asNullableString(map['order_id']),
      serviceRemoteId: TypeHelper.asNullableString(map['service_id']),
      serviceName: map['service_name'] as String,
      quantity: TypeHelper.asDouble(map['quantity']),
      unit: map['unit'] as String,
      pricePerUnit: TypeHelper.asInt(map['price_per_unit']),
      subtotal: TypeHelper.asInt(map['subtotal']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  OrderItem copyWith({
    int? id,
    String? remoteId,
    int? orderId,
    String? orderRemoteId,
    int? serviceId,
    String? serviceRemoteId,
    String? serviceName,
    double? quantity,
    String? unit,
    int? pricePerUnit,
    int? subtotal,
    DateTime? createdAt,
  }) {
    return OrderItem(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      orderId: orderId ?? this.orderId,
      orderRemoteId: orderRemoteId ?? this.orderRemoteId,
      serviceId: serviceId ?? this.serviceId,
      serviceRemoteId: serviceRemoteId ?? this.serviceRemoteId,
      serviceName: serviceName ?? this.serviceName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      subtotal: subtotal ?? this.subtotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper: Calculate subtotal from quantity and price
  static int calculateSubtotal(double quantity, int pricePerUnit) {
    return (quantity * pricePerUnit).round();
  }

  @override
  List<Object?> get props => [
        id,
        remoteId,
        orderId,
        orderRemoteId,
        serviceId,
        serviceRemoteId,
        serviceName,
        quantity,
        unit,
        pricePerUnit,
        subtotal,
        createdAt,
      ];
}
