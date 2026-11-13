import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartattend/core/database/database_helper.dart';
import 'package:smartattend/core/services/api_service.dart';
import 'package:smartattend/core/services/location_service.dart';
import 'package:smartattend/core/services/session_service.dart';
import 'package:smartattend/data/models/qr_session_model.dart';
import 'package:smartattend/data/repositories/admin_repository.dart';
import 'package:smartattend/data/repositories/attendance_repository.dart';
import 'package:smartattend/data/repositories/auth_repository.dart';
import 'package:smartattend/data/repositories/qr_repository.dart';
import 'package:smartattend/features/admin/bloc/admin_bloc.dart';
import 'package:smartattend/features/attendance/bloc/attendance_bloc.dart';
import 'package:smartattend/features/auth/bloc/auth_bloc.dart';
import 'package:smartattend/features/qr/bloc/qr_bloc.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late ApiService api;
  late SessionService session;
  late LocationService location;

  late AuthRepository authRepo;
  late AttendanceRepository attendanceRepo;
  late QRRepository qrRepo;
  late AdminRepository adminRepo;

  setUp(() {
    db = DatabaseHelper();
    api = ApiService();
    session = SessionService();
    location = LocationService();

    authRepo = AuthRepository(db: db, api: api, session: session);
    attendanceRepo = AttendanceRepository(db: db, api: api);
    qrRepo = QRRepository(db: db);
    adminRepo = AdminRepository(db: db);
  });

  tearDown(() async {
    await db.close();
    await db.deleteDatabase();
  });

  // ─── AuthBloc Tests ───────────────────────────────────────────────────────

  group('AuthBloc', () {
    late AuthBloc bloc;

    setUp(() {
      bloc = AuthBloc(authRepository: authRepo);
    });

    tearDown(() => bloc.close());

    test('initial state is AuthInitial', () {
      expect(bloc.state, isA<AuthInitial>());
    });

    test('successful employee login emits AuthAuthenticated', () async {
      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AuthLoginRequested(
        email: 'john@test.com',
        password: '123456',
      ));

      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();

      expect(states.any((s) => s is AuthLoading), isTrue);
      expect(states.last, isA<AuthAuthenticated>());
      final auth = states.last as AuthAuthenticated;
      expect(auth.employee.id, 'EMP001');
      expect(auth.employee.role, 'employee');
    });

    test('successful admin login emits AuthAuthenticated with admin role', () async {
      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AuthLoginRequested(
        email: 'admin@test.com',
        password: 'admin123',
      ));

      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();

      expect(states.last, isA<AuthAuthenticated>());
      final auth = states.last as AuthAuthenticated;
      expect(auth.employee.role, 'admin');
    });

    test('invalid login emits AuthError', () async {
      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AuthLoginRequested(
        email: 'nobody@test.com',
        password: '123456',
      ));

      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();

      expect(states.last, isA<AuthError>());
    });

    test('short password triggers validation error without hitting DB', () async {
      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AuthLoginRequested(
        email: 'john@test.com',
        password: '123', // too short
      ));

      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();

      // Should emit AuthError immediately (client validation), not AuthLoading.
      expect(states.last, isA<AuthError>());
      expect(states.any((s) => s is AuthLoading), isFalse);
    });

    test('logout emits AuthUnauthenticated', () async {
      // Login first.
      bloc.add(const AuthLoginRequested(
        email: 'john@test.com',
        password: '123456',
      ));
      await Future.delayed(const Duration(milliseconds: 500));

      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AuthLogoutRequested());
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();

      expect(states.last, isA<AuthUnauthenticated>());
    });
  });

  // ─── AttendanceBloc Tests ─────────────────────────────────────────────────

  group('AttendanceBloc', () {
    late AttendanceBloc bloc;

    setUp(() {
      bloc = AttendanceBloc(
        attendanceRepository: attendanceRepo,
        locationService: location,
      );
    });

    tearDown(() => bloc.close());

    test('initial state is AttendanceInitial', () {
      expect(bloc.state, isA<AttendanceInitial>());
    });

    test('load today emits AttendanceLoaded', () async {
      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AttendanceLoadToday(employeeId: 'EMP001'));
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();

      expect(states.last, isA<AttendanceLoaded>());
      final loaded = states.last as AttendanceLoaded;
      expect(loaded.todayAttendance, isNull); // no record yet
    });

    test('check-in emits AttendanceActionSuccess', () async {
      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AttendanceCheckInRequested(
        employeeId: 'EMP001',
        employeeName: 'John',
      ));

      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();

      expect(states.last, isA<AttendanceActionSuccess>());
      final success = states.last as AttendanceActionSuccess;
      expect(success.isCheckIn, isTrue);
    });

    test('checkout after check-in succeeds', () async {
      // Check in first.
      bloc.add(const AttendanceCheckInRequested(
        employeeId: 'EMP002',
        employeeName: 'Sarah',
      ));
      await Future.delayed(const Duration(milliseconds: 500));

      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AttendanceCheckOutRequested(
        employeeId: 'EMP002',
        employeeName: 'Sarah',
      ));

      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();

      expect(states.last, isA<AttendanceActionSuccess>());
      final success = states.last as AttendanceActionSuccess;
      expect(success.isCheckIn, isFalse);
    });

    test('checkout without check-in emits AttendanceError', () async {
      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      // EMP001 has no record (fresh DB).
      bloc.add(const AttendanceCheckOutRequested(
        employeeId: 'EMP001',
        employeeName: 'John',
      ));

      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, isA<AttendanceError>());
    });

    test('duplicate check-in emits AttendanceError', () async {
      // First check-in.
      bloc.add(const AttendanceCheckInRequested(
        employeeId: 'EMP001',
        employeeName: 'John',
      ));
      await Future.delayed(const Duration(milliseconds: 500));

      // Checkout.
      bloc.add(const AttendanceCheckOutRequested(
        employeeId: 'EMP001',
        employeeName: 'John',
      ));
      await Future.delayed(const Duration(milliseconds: 500));

      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      // Try check-in again (both check-in and check-out already exist).
      bloc.add(const AttendanceCheckInRequested(
        employeeId: 'EMP001',
        employeeName: 'John',
      ));

      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();

      expect(states.last, isA<AttendanceError>());
    });
  });

  // ─── QRBloc Tests ─────────────────────────────────────────────────────────

  group('QRBloc', () {
    late QRBloc bloc;

    setUp(() {
      bloc = QRBloc(qrRepository: qrRepo);
    });

    tearDown(() => bloc.close());

    test('initial state is QRInitial', () {
      expect(bloc.state, isA<QRInitial>());
    });

    test('generate emits QRGenerated with valid payload', () async {
      final states = <QRState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const QRGenerateRequested());
      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();

      expect(states.any((s) => s is QRGenerating), isTrue);
      expect(states.last, isA<QRGenerated>());

      final generated = states.last as QRGenerated;
      expect(generated.payload, isNotEmpty);
      expect(generated.remainingSeconds, greaterThan(0));
    });

    test('validate valid QR emits QRValidationSuccess', () async {
      // Generate a session first.
      bloc.add(const QRGenerateRequested());
      await Future.delayed(const Duration(milliseconds: 400));

      final generated = bloc.state as QRGenerated;
      final states = <QRState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(QRValidateRequested(rawPayload: generated.payload));
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, isA<QRValidationSuccess>());
    });

    test('validate with invalid token emits QRError', () async {
      // Generate a valid session.
      bloc.add(const QRGenerateRequested());
      await Future.delayed(const Duration(milliseconds: 400));

      final generated = bloc.state as QRGenerated;
      // Tamper the payload token.
      final tamperedPayload = generated.payload.replaceAll(
        generated.session.token.substring(0, 8),
        'xxxxxxxx',
      );

      final states = <QRState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(QRValidateRequested(rawPayload: tamperedPayload));
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(
        states.last,
        anyOf(isA<QRError>(), isA<QRExpired>()),
        reason: 'Tampered payload should fail validation',
      );
    });

    test('expired QR session model returns isExpired = true', () {
      final now = DateTime.now();
      final expiredSession = _makeExpiredSession(now);
      expect(expiredSession.isExpired, isTrue);
      expect(expiredSession.remainingSeconds, 0);
    });
  });

  // ─── AdminBloc Tests ──────────────────────────────────────────────────────

  group('AdminBloc', () {
    late AdminBloc bloc;

    setUp(() {
      bloc = AdminBloc(adminRepository: adminRepo);
    });

    tearDown(() => bloc.close());

    test('initial state is AdminInitial', () {
      expect(bloc.state, isA<AdminInitial>());
    });

    test('load dashboard emits AdminDashboardLoaded', () async {
      final states = <AdminState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AdminDashboardLoadRequested());
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, isA<AdminDashboardLoaded>());
      final dashboard = states.last as AdminDashboardLoaded;
      // Seeded employees: 2 employees (not admin).
      expect(dashboard.totalEmployees, 2);
      expect(dashboard.presentToday, 0); // no attendance yet
    });

    test('load employees emits AdminEmployeesLoaded', () async {
      final states = <AdminState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AdminEmployeesLoadRequested());
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, isA<AdminEmployeesLoaded>());
      final loaded = states.last as AdminEmployeesLoaded;
      expect(loaded.employees.length, greaterThanOrEqualTo(3)); // includes admin
    });

    test('load attendance emits AdminAttendanceLoaded', () async {
      final states = <AdminState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AdminAttendanceLoadRequested());
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, isA<AdminAttendanceLoaded>());
    });

    test('refresh emits updated AdminDashboardLoaded', () async {
      final states = <AdminState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AdminRefreshRequested());
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, isA<AdminDashboardLoaded>());
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────

QRSessionModel _makeExpiredSession(DateTime now) {
  return QRSessionModel(
    sessionId: 'QRS_EXPIRED',
    createdAt: now.subtract(const Duration(seconds: 90)).toIso8601String(),
    expiresAt: now.subtract(const Duration(seconds: 30)).toIso8601String(),
    token: 'expiredtoken',
    isActive: false,
  );
}
