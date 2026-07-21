import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/core/utils/type_helper.dart';

class Attendance extends Equatable {
  final int? id;
  final String uuid;
  final String outletId;
  final int? userId;
  final String userName;
  final DateTime checkInAt;
  final List<Map<String, dynamic>> checklist;
  final int? checklistDurationSec;
  final DateTime? createdAt;

  const Attendance({
    this.id,
    required this.uuid,
    required this.outletId,
    this.userId,
    required this.userName,
    required this.checkInAt,
    required this.checklist,
    this.checklistDurationSec,
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

  Attendance copyWith({
    int? id,
    String? uuid,
    String? outletId,
    int? userId,
    String? userName,
    DateTime? checkInAt,
    List<Map<String, dynamic>>? checklist,
    int? checklistDurationSec,
    DateTime? createdAt,
  }) {
    return Attendance(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      outletId: outletId ?? this.outletId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      checkInAt: checkInAt ?? this.checkInAt,
      checklist: checklist ?? this.checklist,
      checklistDurationSec: checklistDurationSec ?? this.checklistDurationSec,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        outletId,
        userId,
        userName,
        checkInAt,
        checklist,
        checklistDurationSec,
        createdAt,
      ];
}
