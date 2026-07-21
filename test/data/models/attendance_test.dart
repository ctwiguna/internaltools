import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_laundry_offline_app/data/models/attendance.dart';

void main() {
  group('Attendance Model', () {
    final testDate = DateTime(2026, 7, 20, 8, 30, 0);
    final testChecklist = [
      {'item': 'Lantai dipel', 'checked': 'true', 'checked_at': '2026-07-20T08:30:00'},
      {'item': 'Meja kasir dilap', 'checked': 'true', 'checked_at': '2026-07-20T08:31:00'},
    ];

    test('fromMap parses correctly', () {
      final map = {
        'id': 1,
        'uuid': 'abc-123',
        'outlet_id': '42',
        'user_id': 7,
        'user_name': 'Budi',
        'check_in_at': '2026-07-20T08:30:00.000',
        'checklist_json': json.encode(testChecklist),
        'checklist_duration_sec': 120,
        'created_at': '2026-07-20T08:30:00.000',
      };

      final a = Attendance.fromMap(map);

      expect(a.id, 1);
      expect(a.uuid, 'abc-123');
      expect(a.outletId, '42');
      expect(a.userId, 7);
      expect(a.userName, 'Budi');
      expect(a.checkInAt, testDate);
      expect(a.checklist.length, 2);
      expect(a.checklist[0]['item'], 'Lantai dipel');
      expect(a.checklistDurationSec, 120);
      expect(a.createdAt, testDate);
    });

    test('fromMap handles null checklist_json gracefully', () {
      final map = {
        'id': 2,
        'uuid': 'def-456',
        'outlet_id': '1',
        'user_name': 'Ani',
        'check_in_at': '2026-07-20T09:00:00.000',
        'checklist_json': null,
        'checklist_duration_sec': null,
        'created_at': null,
      };

      final a = Attendance.fromMap(map);
      expect(a.checklist, isEmpty);
      expect(a.checklistDurationSec, isNull);
      expect(a.createdAt, isNull);
    });

    test('toMap serializes correctly', () {
      final a = Attendance(
        id: 3,
        uuid: 'ghi-789',
        outletId: '99',
        userId: 5,
        userName: 'Citra',
        checkInAt: testDate,
        checklist: testChecklist,
        checklistDurationSec: 90,
        createdAt: testDate,
      );

      final map = a.toMap();
      expect(map['id'], 3);
      expect(map['uuid'], 'ghi-789');
      expect(map['outlet_id'], '99');
      expect(map['user_id'], 5);
      expect(map['user_name'], 'Citra');
      expect(map['check_in_at'], '2026-07-20T08:30:00.000');
      expect(json.decode(map['checklist_json'] as String), testChecklist);
      expect(map['checklist_duration_sec'], 90);
      expect(map['created_at'], '2026-07-20T08:30:00.000');
    });

    test('copyWith updates fields', () {
      final a = Attendance(
        uuid: 'x',
        outletId: '1',
        userName: 'Old',
        checkInAt: testDate,
        checklist: [],
      );

      final b = a.copyWith(userName: 'New', checklistDurationSec: 45);

      expect(b.uuid, 'x');
      expect(b.userName, 'New');
      expect(b.checklistDurationSec, 45);
    });

    test('Equatable works', () {
      final a = Attendance(
        uuid: 'same',
        outletId: '1',
        userName: 'User',
        checkInAt: testDate,
        checklist: testChecklist,
      );
      final b = Attendance(
        uuid: 'same',
        outletId: '1',
        userName: 'User',
        checkInAt: testDate,
        checklist: testChecklist,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
