import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/data/models/attendance.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

class AttendanceLoading extends AttendanceState {
  const AttendanceLoading();
}

class AttendanceLoaded extends AttendanceState {
  final List<Attendance> attendances;
  final bool hasCheckedInToday;

  const AttendanceLoaded(this.attendances, {this.hasCheckedInToday = false});

  @override
  List<Object?> get props => [attendances, hasCheckedInToday];
}

class AttendanceCheckInSuccess extends AttendanceState {
  final String message;

  const AttendanceCheckInSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError(this.message);

  @override
  List<Object?> get props => [message];
}
