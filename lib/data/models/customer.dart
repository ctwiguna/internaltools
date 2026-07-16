import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

class Customer extends Equatable {
  final int? id;
  final String? remoteId; // Supabase UUID
  final String? outletId; // Supabase outlet UUID
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final int totalOrders;
  final int totalSpent;
  final DateTime? lastOrderDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    this.id,
    this.remoteId,
    this.outletId,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.lastOrderDate,
    this.createdAt,
    this.updatedAt,
  });

  /// Check if this is a remote (Supabase) customer
  bool get isRemote => remoteId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'outlet_id': outletId,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
      'last_order_date': lastOrderDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Convert to Supabase-compatible map (excludes local id)
  Map<String, dynamic> toSupabaseMap() {
    return {
      if (remoteId != null) 'id': remoteId,
      'outlet_id': outletId,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
      'last_order_date': lastOrderDate?.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: TypeHelper.asNullableInt(map['id']),
      remoteId: TypeHelper.asNullableString(map['remote_id']),
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      name: map['name'] as String,
      phone: TypeHelper.asNullableString(map['phone']),
      address: TypeHelper.asNullableString(map['address']),
      notes: TypeHelper.asNullableString(map['notes']),
      totalOrders: TypeHelper.asInt(map['total_orders']),
      totalSpent: TypeHelper.asInt(map['total_spent']),
      lastOrderDate: map['last_order_date'] != null
          ? DateTime.parse(map['last_order_date'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Create from Supabase response
  factory Customer.fromSupabase(Map<String, dynamic> map) {
    return Customer(
      remoteId: TypeHelper.asNullableString(map['id']),
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      name: map['name'] as String,
      phone: TypeHelper.asNullableString(map['phone']),
      address: TypeHelper.asNullableString(map['address']),
      notes: TypeHelper.asNullableString(map['notes']),
      totalOrders: TypeHelper.asInt(map['total_orders']),
      totalSpent: TypeHelper.asInt(map['total_spent']),
      lastOrderDate: map['last_order_date'] != null
          ? DateTime.parse(map['last_order_date'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Customer copyWith({
    int? id,
    String? remoteId,
    String? outletId,
    String? name,
    String? phone,
    String? address,
    String? notes,
    int? totalOrders,
    int? totalSpent,
    DateTime? lastOrderDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      outletId: outletId ?? this.outletId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool get isLoyalCustomer => totalOrders >= 10;

  int get averageSpentPerOrder =>
      totalOrders > 0 ? (totalSpent / totalOrders).round() : 0;

  String get formattedPhone {
    if (phone == null || phone!.isEmpty) return '-';
    return phone!;
  }

  String get whatsappNumber {
    if (phone == null || phone!.isEmpty) return '';
    String cleaned = phone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    }
    return cleaned;
  }

  @override
  List<Object?> get props => [
        id,
        remoteId,
        outletId,
        name,
        phone,
        address,
        notes,
        totalOrders,
        totalSpent,
        lastOrderDate,
        createdAt,
        updatedAt,
      ];
}
