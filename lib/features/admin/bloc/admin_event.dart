part of 'admin_bloc.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class AdminDashboardLoadRequested extends AdminEvent {
  const AdminDashboardLoadRequested();
}

class AdminEmployeesLoadRequested extends AdminEvent {
  const AdminEmployeesLoadRequested();
}

class AdminAttendanceLoadRequested extends AdminEvent {
  const AdminAttendanceLoadRequested();
}

class AdminRefreshRequested extends AdminEvent {
  const AdminRefreshRequested();
}

/// Load combined employee list with today's attendance status.
class AdminEmployeeStatusLoadRequested extends AdminEvent {
  const AdminEmployeeStatusLoadRequested();
}

/// Load full attendance history for a specific employee.
class AdminEmployeeDetailRequested extends AdminEvent {
  final String employeeId;
  const AdminEmployeeDetailRequested({required this.employeeId});

  @override
  List<Object?> get props => [employeeId];
}

