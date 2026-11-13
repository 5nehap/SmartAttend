part of 'attendance_bloc.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

class AttendanceLoadToday extends AttendanceEvent {
  final String employeeId;

  const AttendanceLoadToday({required this.employeeId});

  @override
  List<Object?> get props => [employeeId];
}

class AttendanceLoadHistory extends AttendanceEvent {
  final String employeeId;

  const AttendanceLoadHistory({required this.employeeId});

  @override
  List<Object?> get props => [employeeId];
}

class AttendanceCheckInRequested extends AttendanceEvent {
  final String employeeId;
  final String employeeName;

  const AttendanceCheckInRequested({
    required this.employeeId,
    required this.employeeName,
  });

  @override
  List<Object?> get props => [employeeId, employeeName];
}

class AttendanceCheckOutRequested extends AttendanceEvent {
  final String employeeId;
  final String employeeName;

  const AttendanceCheckOutRequested({
    required this.employeeId,
    required this.employeeName,
  });

  @override
  List<Object?> get props => [employeeId, employeeName];
}

class AttendanceRefreshRequested extends AttendanceEvent {
  final String employeeId;

  const AttendanceRefreshRequested({required this.employeeId});

  @override
  List<Object?> get props => [employeeId];
}

/// Dispatched after a successful QR scan.
/// AttendanceBloc auto-determines check-in vs check-out.
class AttendanceMarkFromQRRequested extends AttendanceEvent {
  final String employeeId;
  final String employeeName;

  const AttendanceMarkFromQRRequested({
    required this.employeeId,
    required this.employeeName,
  });

  @override
  List<Object?> get props => [employeeId, employeeName];
}
