import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/models/attendance_model.dart';
import '../../../data/models/employee_model.dart';
import '../../../data/repositories/admin_repository.dart';

part 'admin_event.dart';
part 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AdminRepository _adminRepository;

  AdminBloc({required AdminRepository adminRepository})
      : _adminRepository = adminRepository,
        super(const AdminInitial()) {
    on<AdminDashboardLoadRequested>(_onDashboardLoad);
    on<AdminEmployeesLoadRequested>(_onEmployeesLoad);
    on<AdminAttendanceLoadRequested>(_onAttendanceLoad);
    on<AdminRefreshRequested>(_onRefresh);
    on<AdminEmployeeStatusLoadRequested>(_onEmployeeStatusLoad);
    on<AdminEmployeeDetailRequested>(_onEmployeeDetail);
  }

  Future<void> _onDashboardLoad(
    AdminDashboardLoadRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(const AdminLoading());
    try {
      final summary = await _adminRepository.getDashboardSummary();
      emit(AdminDashboardLoaded(
        totalEmployees: summary.totalEmployees,
        presentToday: summary.presentToday,
        pendingToday: summary.pendingToday,
        todayRecords: summary.todayRecords,
      ));
    } catch (e) {
      emit(AdminError(message: 'Failed to load dashboard: ${e.toString()}'));
    }
  }

  Future<void> _onEmployeesLoad(
    AdminEmployeesLoadRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(const AdminLoading());
    try {
      final employees = await _adminRepository.getAllEmployees();
      emit(AdminEmployeesLoaded(employees: employees));
    } catch (e) {
      emit(AdminError(message: 'Failed to load employees: ${e.toString()}'));
    }
  }

  Future<void> _onAttendanceLoad(
    AdminAttendanceLoadRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(const AdminLoading());
    try {
      final records = await _adminRepository.getAllAttendance();
      emit(AdminAttendanceLoaded(records: records));
    } catch (e) {
      emit(AdminError(message: 'Failed to load attendance records: ${e.toString()}'));
    }
  }

  Future<void> _onRefresh(
    AdminRefreshRequested event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final summary = await _adminRepository.getDashboardSummary();
      emit(AdminDashboardLoaded(
        totalEmployees: summary.totalEmployees,
        presentToday: summary.presentToday,
        pendingToday: summary.pendingToday,
        todayRecords: summary.todayRecords,
      ));
    } catch (e) {
      emit(AdminError(message: 'Refresh failed: ${e.toString()}'));
    }
  }

  /// Loads all employees + today's attendance, combined into one state.
  Future<void> _onEmployeeStatusLoad(
    AdminEmployeeStatusLoadRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(const AdminLoading());
    try {
      final summary = await _adminRepository.getDashboardSummary();
      final employees = summary.employees;
      final todayRecords = summary.todayRecords;

      // Map employeeId → today's attendance (nullable).
      final map = <String, AttendanceModel?>{};
      for (final emp in employees) {
        map[emp.id] = null;
      }
      for (final rec in todayRecords) {
        map[rec.employeeId] = rec;
      }

      emit(AdminEmployeeStatusLoaded(
        employees: employees,
        todayAttendanceByEmployee: map,
        totalEmployees: summary.totalEmployees,
        presentToday: summary.presentToday,
        pendingToday: summary.pendingToday,
      ));
    } catch (e) {
      emit(AdminError(message: 'Failed to load employee status: ${e.toString()}'));
    }
  }

  /// Loads full attendance history for a specific employee.
  Future<void> _onEmployeeDetail(
    AdminEmployeeDetailRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(const AdminLoading());
    try {
      final employee = await _adminRepository.getEmployee(event.employeeId);
      if (employee == null) {
        emit(const AdminError(message: 'Employee not found.'));
        return;
      }
      final history =
          await _adminRepository.getAttendanceForEmployee(event.employeeId);
      final total = history.length;
      final completed = history.where((r) => r.hasCheckOut).length;

      emit(AdminEmployeeDetailLoaded(
        employee: employee,
        history: history,
        totalDays: total,
        completedDays: completed,
      ));
    } catch (e) {
      emit(AdminError(message: 'Failed to load employee detail: ${e.toString()}'));
    }
  }
}

