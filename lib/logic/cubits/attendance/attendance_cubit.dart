import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/attendance.dart';
import 'package:flutter_laundry_offline_app/data/repositories/attendance_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/ops_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_attendance_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/attendance/attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _attendanceRepository;
  final SupabaseAttendanceRepository _onlineRepository;
  final OpsRepository _opsRepository;
  final ConnectivityService _connectivity;
  final SupabaseService _supabase;
  List<Attendance> _attendances = [];

  AttendanceCubit({
    AttendanceRepository? attendanceRepository,
    SupabaseAttendanceRepository? onlineRepository,
    OpsRepository? opsRepository,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
  })  : _attendanceRepository = attendanceRepository ?? AttendanceRepository(),
        _onlineRepository = onlineRepository ?? SupabaseAttendanceRepository(),
        _opsRepository = opsRepository ?? OpsRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _supabase = supabase ?? SupabaseService.instance,
        super(const AttendanceInitial());

  List<Attendance> get attendances => _attendances;

  bool get _isOnline => _connectivity.isOnline && _supabase.isAuthenticated;

  Future<void> loadAttendances({int? userId, String? userRemoteId}) async {
    emit(const AttendanceLoading());
    try {
      // Mode online: data dari Supabase (terfilter outlet aktif)
      if (_isOnline) {
        final authUid = _supabase.client.auth.currentUser?.id;
        // "View per user" jika layar meminta user tertentu ATAU memang
        // ada sesi login — riwayat & status absen selalu untuk user login.
        final effectiveUid = userRemoteId ?? ((userId != null) ? authUid : null);

        if (effectiveUid != null) {
          _attendances =
              await _onlineRepository.getAttendanceByUser(effectiveUid);
          final today =
              await _onlineRepository.getTodayAttendance(effectiveUid);
          emit(AttendanceLoaded(_attendances,
              hasCheckedInToday: today != null));
        } else {
          _attendances = await _onlineRepository.getAttendanceByOutlet();
          emit(AttendanceLoaded(_attendances));
        }
        return;
      }

      // Mode offline: data dari SQLite lokal
      if (userId != null) {
        _attendances = await _attendanceRepository.getAttendanceByUser(userId);
      } else {
        _attendances = await _attendanceRepository.getAttendanceByOutlet();
      }

      bool hasCheckedIn = false;
      if (userId != null) {
        final today = await _attendanceRepository.getTodayAttendance(userId);
        hasCheckedIn = today != null;
      }

      emit(AttendanceLoaded(_attendances, hasCheckedInToday: hasCheckedIn));
    } catch (e) {
      emit(AttendanceError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> checkIn({
    required int? userId,
    String? userRemoteId,
    required String userName,
    required List<Map<String, String>> checklist,
    int? durationSec,
    double lipatKg = 0,
    double setrikaKg = 0,
  }) async {
    emit(const AttendanceLoading());
    try {
      if (_isOnline) {
        await _onlineRepository.checkIn(
          userName: userName,
          checklist: checklist,
          checklistDurationSec: durationSec ?? 0,
          lipatKg: lipatKg,
          setrikaKg: setrikaKg,
        );
      } else {
        await _opsRepository.checkIn(
          userId: userId,
          userName: userName,
          checklist: checklist,
          checklistDurationSec: durationSec ?? 0,
        );
      }

      emit(const AttendanceCheckInSuccess('Absensi berhasil dicatat'));
      await loadAttendances(userId: userId, userRemoteId: userRemoteId);
    } catch (e) {
      emit(AttendanceError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
