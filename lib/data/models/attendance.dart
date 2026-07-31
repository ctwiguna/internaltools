import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

class Attendance extends Equatable {
  final int? id;
  final String uuid;
  final String outletId;
  final int? userId;
  final String? userRemoteId; // Supabase user UUID
  final String userName;
  final DateTime checkInAt;
  final List<Map<String, dynamic>> checklist;
  final int? checklistDurationSec;
  final double lipatKg; // laporan kinerja: lipat/packing/wangi (kg)
  final double setrikaKg; // laporan kinerja: setrika (kg)
  final DateTime? createdAt;

  const Attendance({
    this.id,
    required this.uuid,
    required this.outletId,
    this.userId,
    this.userRemoteId,
    required this.userName,
    required this.checkInAt,
    required this.checklist,
    this.checklistDurationSec,
    this.lipatKg = 0,
    this.setrikaKg = 0,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'outlet_id': outletId,
      'user_id': userId,
      'user_name': userName,
      'check_in_at': checkInAt.toIso8601String(),
      'checklist_json': json.encode(checklist),
      'checklist_duration_sec': checklistDurationSec,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Convert to Supabase-compatible map.
  /// Di cloud: PK = id (uuid), user_id = auth UUID, checklist = jsonb.
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': uuid,
      'outlet_id': outletId,
      'user_id': userRemoteId,
      'user_name': userName,
      'check_in_at': checkInAt.toIso8601String(),
      'checklist': checklist,
      'checklist_duration_sec': checklistDurationSec,
      'lipat_kg': lipatKg,
      'setrika_kg': setrikaKg,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    final rawChecklist = map['checklist_json'];
    List<Map<String, dynamic>> parsedChecklist = [];
    if (rawChecklist != null) {
      try {
        final decoded = json.decode(rawChecklist as String);
        if (decoded is List) {
          parsedChecklist = decoded
              .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
              .toList();
        }
      } catch (_) {
        parsedChecklist = [];
      }
    }

    return Attendance(
      id: TypeHelper.asNullableInt(map['id']),
      uuid: TypeHelper.asString(map['uuid']),
      outletId: TypeHelper.asString(map['outlet_id']),
      userId: TypeHelper.asNullableInt(map['user_id']),
      userName: TypeHelper.asString(map['user_name']),
      checkInAt: DateTime.parse(map['check_in_at'] as String),
      checklist: parsedChecklist,
      checklistDurationSec: TypeHelper.asNullableInt(map['checklist_duration_sec']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Create from Supabase response (checklist sudah berupa jsonb/List).
  factory Attendance.fromSupabase(Map<String, dynamic> map) {
    List<Map<String, dynamic>> parsedChecklist = [];
    final raw = map['checklist'];
    if (raw is List) {
      parsedChecklist = raw
          .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList();
    } else if (raw is String) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          parsedChecklist = decoded
              .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
              .toList();
        }
      } catch (_) {
        parsedChecklist = [];
      }
    }

    return Attendance(
      uuid: TypeHelper.asString(map['id']),
      outletId: TypeHelper.asString(map['outlet_id']),
      userRemoteId: TypeHelper.asNullableString(map['user_id']),
      userName: TypeHelper.asString(map['user_name']),
      checkInAt: DateTime.parse(map['check_in_at'] as String),
      checklist: parsedChecklist,
      checklistDurationSec: TypeHelper.asNullableInt(map['checklist_duration_sec']),
      lipatKg: (map['lipat_kg'] as num?)?.toDouble() ?? 0,
      setrikaKg: (map['setrika_kg'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Attendance copyWith({
    int? id,
    String? uuid,
    String? outletId,
    int? userId,
    String? userRemoteId,
    String? userName,
    DateTime? checkInAt,
    List<Map<String, dynamic>>? checklist,
    int? checklistDurationSec,
    double? lipatKg,
    double? setrikaKg,
    DateTime? createdAt,
  }) {
    return Attendance(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      outletId: outletId ?? this.outletId,
      userId: userId ?? this.userId,
      userRemoteId: userRemoteId ?? this.userRemoteId,
      userName: userName ?? this.userName,
      checkInAt: checkInAt ?? this.checkInAt,
      checklist: checklist ?? this.checklist,
      checklistDurationSec: checklistDurationSec ?? this.checklistDurationSec,
      lipatKg: lipatKg ?? this.lipatKg,
      setrikaKg: setrikaKg ?? this.setrikaKg,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        outletId,
        userId,
        userRemoteId,
        userName,
        checkInAt,
        checklist,
        checklistDurationSec,
        lipatKg,
        setrikaKg,
        createdAt,
      ];
}
