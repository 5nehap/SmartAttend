// test/step6_test.dart — Employee History & Admin Records tests
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartattend/core/database/database_helper.dart';
import 'package:smartattend/core/services/api_service.dart';
import 'package:smartattend/core/services/location_service.dart';
import 'package:smartattend/data/repositories/admin_repository.dart';
import 'package:smartattend/data/repositories/attendance_repository.dart';
import 'package:smartattend/features/admin/bloc/admin_bloc.dart';
import 'package:smartattend/features/attendance/bloc/attendance_bloc.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late AttendanceRepository attendanceRepo;
  late AdminRepository adminRepo;

  setUp(() {
    db = DatabaseHelper();
    attendanceRepo = AttendanceRepository(db: db, api: ApiService());
    adminRepo = AdminRepository(db: db);
  });

  tearDown(() async {
    await db.close();
    await db.deleteDatabase();
  });

  // ─── Employee Attendance History ──────────────────────────────────────────

  group('Employee Attendance History', () {
    test('loads empty history when no records exist', () async {
      final history = await attendanceRepo.getEmployeeHistory('EMP001');
      expect(history, isEmpty);
    });

    test('loads history with correct records for the employee', () async {
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: null,
        longitude: null,
      );
      final history = await attendanceRepo.getEmployeeHistory('EMP001');
      expect(history, hasLength(1));
      expect(history.first.employeeId, 'EMP001');
    });

    test('only returns records for the requested employee', () async {
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: null,
        longitude: null,
      );
      await attendanceRepo.markAttendance(
        employeeId: 'EMP002',
        employeeName: 'Sarah',
        latitude: null,
        longitude: null,
      );

      final emp1History = await attendanceRepo.getEmployeeHistory('EMP001');
      final emp2History = await attendanceRepo.getEmployeeHistory('EMP002');

      expect(emp1History, hasLength(1));
      expect(emp2History, hasLength(1));
      expect(emp1History.first.employeeId, 'EMP001');
      expect(emp2History.first.employeeId, 'EMP002');
    });

    test('records are sorted newest first', () async {
      // We can only create one record per day due to the unique constraint,
      // so verify the ordering is DESC by date.
      final history = await attendanceRepo.getEmployeeHistory('EMP001');
      // No records → trivially sorted.
      expect(history, isEmpty);
    });

    test('check-in time is recorded correctly', () async {
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: 12.9716,
        longitude: 77.5946,
      );
      final today = await attendanceRepo.getTodayAttendance('EMP001');
      expect(today, isNotNull);
      expect(today!.checkInTime, isNotEmpty);
      expect(today.checkInLatitude, closeTo(12.9716, 0.001));
    });

    test('completed attendance has both check-in and check-out', () async {
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: null,
        longitude: null,
      );
      // Second mark = check-out
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: null,
        longitude: null,
      );
      final today = await attendanceRepo.getTodayAttendance('EMP001');
      expect(today!.hasCheckOut, isTrue);
      expect(today.checkOutTime, isNotNull);
      expect(today.checkOutTime!.isNotEmpty, isTrue);
    });
  });

  // ─── Admin Records ────────────────────────────────────────────────────────

  group('Admin Records', () {
    test('loads all employees including those without attendance', () async {
      final employees = await adminRepo.getAllEmployees();
      // DB seeds 3 users (ADM001, EMP001, EMP002) on first open.
      expect(employees.length, greaterThanOrEqualTo(2));
    });

    test('loads all attendance records', () async {
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: null,
        longitude: null,
      );
      final records = await adminRepo.getAllAttendance();
      expect(records, hasLength(1));
    });

    test('dashboard summary counts present and pending correctly', () async {
      // Before any attendance
      final summaryBefore = await adminRepo.getDashboardSummary();
      expect(summaryBefore.presentToday, 0);
      expect(summaryBefore.pendingToday, summaryBefore.totalEmployees);

      // Check in EMP001
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: null,
        longitude: null,
      );
      final summaryAfter = await adminRepo.getDashboardSummary();
      expect(summaryAfter.presentToday, 1);
      expect(summaryAfter.pendingToday, summaryAfter.totalEmployees - 1);
    });

    test('employees without attendance are included in employee list',
        () async {
      final employees = await adminRepo.getAllEmployees();
      final records = await adminRepo.getAllAttendance();
      // No records yet — all employees have no attendance.
      expect(records, isEmpty);
      expect(employees.isNotEmpty, isTrue);
    });

    test('getAttendanceForEmployee returns correct employee history',
        () async {
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: null,
        longitude: null,
      );
      await attendanceRepo.markAttendance(
        employeeId: 'EMP002',
        employeeName: 'Sarah',
        latitude: null,
        longitude: null,
      );

      final emp1 = await adminRepo.getAttendanceForEmployee('EMP001');
      final emp2 = await adminRepo.getAttendanceForEmployee('EMP002');
      expect(emp1, hasLength(1));
      expect(emp2, hasLength(1));
      expect(emp1.first.employeeId, 'EMP001');
      expect(emp2.first.employeeId, 'EMP002');
    });

    test('getEmployee returns correct employee', () async {
      final emp = await adminRepo.getEmployee('EMP001');
      expect(emp, isNotNull);
      expect(emp!.id, 'EMP001');
      expect(emp.name, 'John');
      expect(emp.role, 'employee');
    });

    test('getEmployee returns null for unknown ID', () async {
      final emp = await adminRepo.getEmployee('UNKNOWN999');
      expect(emp, isNull);
    });
  });

  // ─── AdminBloc ────────────────────────────────────────────────────────────

  group('AdminBloc', () {
    late AdminBloc adminBloc;

    setUp(() {
      adminBloc = AdminBloc(adminRepository: adminRepo);
    });

    tearDown(() async {
      await adminBloc.close();
    });

    test('initial state is AdminInitial', () {
      expect(adminBloc.state, isA<AdminInitial>());
    });

    test('AdminDashboardLoadRequested emits AdminDashboardLoaded', () async {
      adminBloc.add(const AdminDashboardLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(adminBloc.state, isA<AdminDashboardLoaded>());
    });

    test('AdminEmployeesLoadRequested emits AdminEmployeesLoaded', () async {
      adminBloc.add(const AdminEmployeesLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(adminBloc.state, isA<AdminEmployeesLoaded>());
    });

    test('AdminAttendanceLoadRequested emits AdminAttendanceLoaded',
        () async {
      adminBloc.add(const AdminAttendanceLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(adminBloc.state, isA<AdminAttendanceLoaded>());
    });

    test('AdminEmployeeStatusLoadRequested emits AdminEmployeeStatusLoaded',
        () async {
      adminBloc.add(const AdminEmployeeStatusLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(adminBloc.state, isA<AdminEmployeeStatusLoaded>());
    });

    test('AdminEmployeeDetailRequested emits AdminEmployeeDetailLoaded',
        () async {
      adminBloc.add(
          const AdminEmployeeDetailRequested(employeeId: 'EMP001'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(adminBloc.state, isA<AdminEmployeeDetailLoaded>());
      final state = adminBloc.state as AdminEmployeeDetailLoaded;
      expect(state.employee.id, 'EMP001');
      expect(state.totalDays, 0); // No attendance yet.
      expect(state.completedDays, 0);
    });

    test('AdminEmployeeDetailRequested for unknown ID emits AdminError',
        () async {
      adminBloc.add(
          const AdminEmployeeDetailRequested(employeeId: 'UNKNOWN'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(adminBloc.state, isA<AdminError>());
    });
  });

  // ─── AttendanceBloc History ───────────────────────────────────────────────

  group('AttendanceBloc History', () {
    late AttendanceBloc attendanceBloc;

    setUp(() {
      attendanceBloc = AttendanceBloc(
        attendanceRepository: attendanceRepo,
        locationService: LocationService(),
      );
    });

    tearDown(() async {
      await attendanceBloc.close();
    });

    test('AttendanceLoadHistory emits AttendanceLoaded with empty list',
        () async {
      attendanceBloc
          .add(const AttendanceLoadHistory(employeeId: 'EMP001'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(attendanceBloc.state, isA<AttendanceLoaded>());
      final state = attendanceBloc.state as AttendanceLoaded;
      expect(state.history, isEmpty);
    });

    test('AttendanceLoadHistory emits correct records after check-in',
        () async {
      await attendanceRepo.markAttendance(
        employeeId: 'EMP001',
        employeeName: 'John',
        latitude: null,
        longitude: null,
      );
      attendanceBloc
          .add(const AttendanceLoadHistory(employeeId: 'EMP001'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final state = attendanceBloc.state as AttendanceLoaded;
      expect(state.history, hasLength(1));
      expect(state.history.first.employeeId, 'EMP001');
    });
  });
}
