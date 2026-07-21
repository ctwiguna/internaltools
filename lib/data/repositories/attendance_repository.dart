import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/attendance.dart';

class AttendanceRepository {
  Future<List<Attendance>> getAttendanceByOutlet({String? outletId, int limit = 50}) async {
    final db = await DatabaseHelper.instance.database;
    final outletIdStr = outletId ?? OutletService.instance.currentOutletIdStr;
    if (outletIdStr == null) return [];

    final rows = await db.query(
      'attendance',
      where: 'outlet_id = ?',
      whereArgs: [outletIdStr],
      orderBy: 'check_in_at DESC',
      limit: limit,
    );
    return rows.map((e) => Attendance.fromMap(e)).toList();
  }

  Future<List<Attendance>> getAttendanceByUser(int? userId, {int limit = 50}) async {
    final db = await DatabaseHelper.instance.database;
    final outletIdStr = OutletService.instance.currentOutletIdStr;
    if (outletIdStr == null) return [];

    final rows = await db.query(
      'attendance',
      where: 'outlet_id = ? AND user_id = ?',
      whereArgs: [outletIdStr, userId],
      orderBy: 'check_in_at DESC',
      limit: limit,
    );
    return rows.map((e) => Attendance.fromMap(e)).toList();
  }

  Future<Attendance?> getTodayAttendance(int? userId) async {
    final db = await DatabaseHelper.instance.database;
    final outletIdStr = OutletService.instance.currentOutletIdStr;
    if (outletIdStr == null) return null;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'attendance',
      where: 'outlet_id = ? AND user_id = ? AND check_in_at >= ? AND check_in_at <= ?',
      whereArgs: [outletIdStr, userId, startOfDay, endOfDay],
      orderBy: 'check_in_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Attendance.fromMap(rows.first);
  }
}
