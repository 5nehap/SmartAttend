part of 'attendance_bloc.dart';

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
  final AttendanceModel? todayAttendance;
  final List<AttendanceModel> history;

  const AttendanceLoaded({
    this.todayAttendance,
    this.history = const [],
  });

  @override
  List<Object?> get props => [todayAttendance, history];
}

class AttendanceActionLoading extends AttendanceState {
  final String message;

  const AttendanceActionLoading({this.message = 'Processing...'});

  @override
  List<Object?> get props => [message];
}

class AttendanceActionSuccess extends AttendanceState {
  final String message;
  final AttendanceModel? updatedRecord;
  final bool isCheckIn;

  const AttendanceActionSuccess({
    required this.message,
    this.updatedRecord,
    this.isCheckIn = true,
  });

  @override
  List<Object?> get props => [message, updatedRecord, isCheckIn];
}

class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError({required this.message});

  @override
  List<Object?> get props => [message];
}
