import 'package:uuid/uuid.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/attendance.dart';

/// Repository absensi dari Supabase.
/// Semua query terfilter outlet aktif (OutletService.currentOutletUuid).
class SupabaseAttendanceRepository {
  static const _uuidGen = Uuid();

  final SupabaseService _supabase;

  SupabaseAttendanceRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  String? get _outletUuid => OutletService.instance.currentOutletUuid;

  /// Riwayat absensi satu outlet (terbaru dulu).
  Future<List<Attendance>> getAttendanceByOutlet({int limit = 50}) async {
    var query = _supabase.client.from('attendance').select();

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);

    final data =
        await query.order('check_in_at', ascending: false).limit(limit);

    return (data as List)
        .map((map) => Attendance.fromSupabase(map as Map<String, dynamic>))
        .toList();
  }

  /// Riwayat absensi satu user (berdasarkan auth UUID) di outlet aktif.
  Future<List<Attendance>> getAttendanceByUser(
    String? userRemoteId, {
    int limit = 50,
  }) async {
    if (userRemoteId == null) return getAttendanceByOutlet(limit: limit);

    var query = _supabase.client
        .from('attendance')
        .select()
        .eq('user_id', userRemoteId);

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);

    final data =
        await query.order('check_in_at', ascending: false).limit(limit);

    return (data as List)
        .map((map) => Attendance.fromSupabase(map as Map<String, dynamic>))
        .toList();
  }

  /// Absensi user hari ini (untuk status "Sudah Absen").
  Future<Attendance?> getTodayAttendance(String? userRemoteId) async {
    if (userRemoteId == null) return null;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    var query = _supabase.client
        .from('attendance')
        .select()
        .eq('user_id', userRemoteId)
        .gte('check_in_at', startOfDay.toIso8601String())
        .lte('check_in_at', endOfDay.toIso8601String());

    final uuid = _outletUuid;
    if (uuid != null) query = query.eq('outlet_id', uuid);

    final data =
        await query.order('check_in_at', ascending: false).limit(1);

    if ((data as List).isEmpty) return null;
    return Attendance.fromSupabase(data.first);
  }

  /// Catat absen masuk + checklist + laporan kg ke Supabase.
  /// user_id diambil dari sesi auth yang sedang login.
  Future<String> checkIn({
    required String userName,
    required List<Map<String, String>> checklist,
    required int checklistDurationSec,
    double lipatKg = 0,
    double setrikaKg = 0,
  }) async {
    final outletUuid = _outletUuid;
    if (outletUuid == null) {
      throw Exception('Outlet aktif belum dipilih');
    }

    final uuid = _uuidGen.v4();
    final authUserId = _supabase.client.auth.currentUser?.id;

    await _supabase.client.from('attendance').insert({
      'id': uuid,
      'outlet_id': outletUuid,
      'user_id': authUserId,
      'user_name': userName,
      'check_in_at': DateTime.now().toIso8601String(),
      'checklist': checklist,
      'checklist_duration_sec': checklistDurationSec,
      'lipat_kg': lipatKg,
      'setrika_kg': setrikaKg,
    });

    return uuid;
  }
}
