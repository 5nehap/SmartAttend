part of 'admin_bloc.dart';

abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminDashboardLoaded extends AdminState {
  final int totalEmployees;
  final int presentToday;
  final int pendingToday;
  final List<AttendanceModel> todayRecords;

  const AdminDashboardLoaded({
    required this.totalEmployees,
    required this.presentToday,
    required this.pendingToday,
    required this.todayRecords,
  });

  @override
  List<Object?> get props => [
        totalEmployees,
        presentToday,
        pendingToday,
        todayRecords,
      ];
}

class AdminEmployeesLoaded extends AdminState {
  final List<EmployeeModel> employees;

  const AdminEmployeesLoaded({required this.employees});

  @override
  List<Object?> get props => [employees];
}

class AdminAttendanceLoaded extends AdminState {
  final List<AttendanceModel> records;

  const AdminAttendanceLoaded({required this.records});

  @override
  List<Object?> get props => [records];
}

/// Combined employee list with today's attendance status.
class AdminEmployeeStatusLoaded extends AdminState {
  final List<EmployeeModel> employees;
  final Map<String, AttendanceModel?> todayAttendanceByEmployee;
  final int totalEmployees;
  final int presentToday;
  final int pendingToday;

  const AdminEmployeeStatusLoaded({
    required this.employees,
    required this.todayAttendanceByEmployee,
    required this.totalEmployees,
    required this.presentToday,
    required this.pendingToday,
  });

  @override
  List<Object?> get props => [
        employees,
        todayAttendanceByEmployee,
        totalEmployees,
        presentToday,
        pendingToday,
      ];
}

/// Full history for a single employee (admin detail view).
class AdminEmployeeDetailLoaded extends AdminState {
  final EmployeeModel employee;
  final List<AttendanceModel> history;
  final int totalDays;
  final int completedDays;

  const AdminEmployeeDetailLoaded({
    required this.employee,
    required this.history,
    required this.totalDays,
    required this.completedDays,
  });

  @override
  List<Object?> get props => [employee, history, totalDays, completedDays];
}

class AdminError extends AdminState {
  final String message;

  const AdminError({required this.message});

  @override
  List<Object?> get props => [message];
}

