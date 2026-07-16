import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

enum ServiceUnit { kg, pcs }

extension ServiceUnitExtension on ServiceUnit {
  String get value {
    switch (this) {
      case ServiceUnit.kg:
        return 'kg';
      case ServiceUnit.pcs:
        return 'pcs';
    }
  }

  String get displayName {
    switch (this) {
      case ServiceUnit.kg:
        return 'Kilogram';
      case ServiceUnit.pcs:
        return 'Pieces';
    }
  }

  static ServiceUnit fromString(String value) {
    switch (value.toLowerCase()) {
      case 'kg':
        return ServiceUnit.kg;
      case 'pcs':
        return ServiceUnit.pcs;
      default:
        return ServiceUnit.kg;
    }
  }
}

class Service extends Equatable {
  final int? id;
  final String? remoteId; // Supabase UUID
  final String? outletId; // Supabase outlet UUID
  final String name;
  final ServiceUnit unit;
  final int price;
  final int durationDays;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Service({
    this.id,
    this.remoteId,
    this.outletId,
    required this.name,
    required this.unit,
    required this.price,
    this.durationDays = 3,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Check if this is a remote (Supabase) service
  bool get isRemote => remoteId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'outlet_id': outletId,
      'name': name,
      'unit': unit.value,
      'price': price,
      'duration_days': durationDays,
      'is_active': isActive ? 1 : 0,
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
      'unit': unit.value,
      'price': price,
      'duration_days': durationDays,
      'is_active': isActive,
    };
  }

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      id: TypeHelper.asNullableInt(map['id']),
      remoteId: TypeHelper.asNullableString(map['remote_id']),
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      name: map['name'] as String,
      unit: ServiceUnitExtension.fromString(map['unit'] as String),
      price: TypeHelper.asInt(map['price']),
      durationDays: TypeHelper.asInt(map['duration_days'], 3),
      isActive: TypeHelper.asBool(map['is_active'], true),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Create from Supabase response
  factory Service.fromSupabase(Map<String, dynamic> map) {
    return Service(
      remoteId: TypeHelper.asNullableString(map['id']),
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      name: map['name'] as String,
      unit: ServiceUnitExtension.fromString(map['unit'] as String),
      price: TypeHelper.asInt(map['price']),
      durationDays: TypeHelper.asInt(map['duration_days'], 3),
      isActive: TypeHelper.asBool(map['is_active'], true),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Service copyWith({
    int? id,
    String? remoteId,
    String? outletId,
    String? name,
    ServiceUnit? unit,
    int? price,
    int? durationDays,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Service(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      outletId: outletId ?? this.outletId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      durationDays: durationDays ?? this.durationDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        remoteId,
        outletId,
        name,
        unit,
        price,
        durationDays,
        isActive,
        createdAt,
        updatedAt,
      ];
}
