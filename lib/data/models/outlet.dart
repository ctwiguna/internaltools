import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

class Outlet extends Equatable {
  final int? id;
  final String? remoteId; // Supabase UUID
  final String name;
  final String? displayName; // Nama laundry yang tercetak di nota
  final String? address;
  final String? phone;
  final String invoicePrefix;
  final String? ownerId; // Supabase auth user UUID
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Outlet({
    this.id,
    this.remoteId,
    required this.name,
    this.displayName,
    this.address,
    this.phone,
    this.invoicePrefix = 'INV',
    this.ownerId,
    this.createdAt,
    this.updatedAt,
  });

  /// Check if this outlet is synced with Supabase
  bool get isRemote => remoteId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'name': name,
      'display_name': displayName,
      'address': address,
      'phone': phone,
      'invoice_prefix': invoicePrefix,
      'owner_id': ownerId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Convert to Supabase-compatible map
  Map<String, dynamic> toSupabaseMap() {
    return {
      if (remoteId != null) 'id': remoteId,
      'name': name,
      'display_name': displayName,
      'address': address,
      'phone': phone,
      'invoice_prefix': invoicePrefix,
      'owner_id': ownerId,
    };
  }

  factory Outlet.fromMap(Map<String, dynamic> map) {
    return Outlet(
      id: TypeHelper.asNullableInt(map['id']),
      remoteId: TypeHelper.asNullableString(map['remote_id']),
      name: map['name'] as String,
      displayName: TypeHelper.asNullableString(map['display_name']),
      address: TypeHelper.asNullableString(map['address']),
      phone: TypeHelper.asNullableString(map['phone']),
      invoicePrefix: TypeHelper.asNullableString(map['invoice_prefix']) ?? 'INV',
      ownerId: TypeHelper.asNullableString(map['owner_id']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  factory Outlet.fromSupabase(Map<String, dynamic> map) {
    return Outlet(
      remoteId: TypeHelper.asNullableString(map['id']),
      name: map['name'] as String,
      displayName: TypeHelper.asNullableString(map['display_name']),
      address: TypeHelper.asNullableString(map['address']),
      phone: TypeHelper.asNullableString(map['phone']),
      invoicePrefix: TypeHelper.asNullableString(map['invoice_prefix']) ?? 'INV',
      ownerId: TypeHelper.asNullableString(map['owner_id']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Outlet copyWith({
    int? id,
    String? remoteId,
    String? name,
    String? displayName,
    String? address,
    String? phone,
    String? invoicePrefix,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Outlet(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        remoteId,
        name,
        displayName,
        address,
        phone,
        invoicePrefix,
        ownerId,
        createdAt,
        updatedAt,
      ];
}
