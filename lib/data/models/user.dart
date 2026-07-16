import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

enum UserRole { owner, kasir }

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.owner:
        return 'owner';
      case UserRole.kasir:
        return 'kasir';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.kasir:
        return 'Kasir';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'kasir':
        return UserRole.kasir;
      default:
        return UserRole.kasir;
    }
  }
}

class User extends Equatable {
  final int? id;
  final String? remoteId; // Supabase UUID
  final String username;
  final String passwordHash;
  final String name;
  final UserRole role;
  final bool isActive;
  final String? outletId; // Supabase outlet UUID
  final String? outletName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    this.id,
    this.remoteId,
    required this.username,
    this.passwordHash = '',
    required this.name,
    required this.role,
    this.isActive = true,
    this.outletId,
    this.outletName,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'username': username,
      'password_hash': passwordHash,
      'name': name,
      'role': role.value,
      'is_active': isActive ? 1 : 0,
      'outlet_id': outletId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: TypeHelper.asNullableInt(map['id']),
      remoteId: TypeHelper.asNullableString(map['remote_id']),
      username: map['username'] as String,
      passwordHash: TypeHelper.asNullableString(map['password_hash']) ?? '',
      name: map['name'] as String,
      role: UserRoleExtension.fromString(map['role'] as String),
      isActive: TypeHelper.asBool(map['is_active'], true),
      outletId: TypeHelper.asNullableString(map['outlet_id']),
      outletName: TypeHelper.asNullableString(map['outlet_name']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  User copyWith({
    int? id,
    String? remoteId,
    String? username,
    String? passwordHash,
    String? name,
    UserRole? role,
    bool? isActive,
    String? outletId,
    String? outletName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      outletId: outletId ?? this.outletId,
      outletName: outletName ?? this.outletName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if user is from Supabase (online)
  bool get isRemoteUser => remoteId != null;

  // Permission checks
  bool get canManageUsers => role == UserRole.owner;
  bool get canManageServices => role == UserRole.owner;
  bool get canAccessReports => role == UserRole.owner;
  bool get canAccessSettings => role == UserRole.owner;
  bool get canDeleteOrders => role == UserRole.owner;
  bool get canExportData => role == UserRole.owner;

  @override
  List<Object?> get props => [
        id,
        remoteId,
        username,
        passwordHash,
        name,
        role,
        isActive,
        outletId,
        outletName,
        createdAt,
        updatedAt,
      ];
}
