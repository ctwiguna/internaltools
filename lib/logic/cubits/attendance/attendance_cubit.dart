import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/data/models/attendance.dart';
import 'package:flutter_laundry_offline_app/data/repositories/attendance_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/ops_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/attendance/attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _attendanceRepository;
  final OpsRepository _opsRepository;
  List<Attendance> _attendances = [];

  AttendanceCubit({
    AttendanceRepository? attendanceRepository,
    OpsRepository? opsRepository,
  })  : _attendanceRepository = attendanceRepository ?? AttendanceRepository(),
        _opsRepository = opsRepository ?? OpsRepository(),
        super(const AttendanceInitial());

  List<Attendance> get attendances => _attendances;

  Future<void> loadAttendances({int? userId}) async {
    emit(const AttendanceLoading());
    try {
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
    required String userName,
    required List<Map<String, String>> checklist,
    int? durationSec,
  }) async {
    emit(const AttendanceLoading());
    try {
      await _opsRepository.checkIn(
        userId: userId,
        userName: userName,
        checklist: checklist,
        checklistDurationSec: durationSec ?? 0,
      );

      emit(const AttendanceCheckInSuccess('Absensi berhasil dicatat'));
      await loadAttendances(userId: userId);
    } catch (e) {
      emit(AttendanceError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
