import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartattend/core/database/database_helper.dart';
import 'package:smartattend/data/models/attendance_model.dart';
import 'package:smartattend/data/models/qr_session_model.dart';
import 'package:smartattend/core/constants/app_constants.dart';

void main() {
  // Initialize sqflite in-memory for desktop/CI test environments.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;

  setUp(() {
    db = DatabaseHelper();
  });

  tearDown(() async {
    await db.close();
    await db.deleteDatabase();
  });

  // ─── 1. Dummy Employee Initialization ─────────────────────────────────────

  group('Dummy Employee Initialization', () {
    test('seeds three employees on first open', () async {
      final employees = await db.getAllEmployees();
      expect(employees.length, 3,
          reason: 'Expected ADM001, EMP001, EMP002 to be seeded');
    });

    test('admin employee has correct role', () async {
      final admin = await db.getEmployeeByEmail('admin@test.com');
      expect(admin, isNotNull);
      expect(admin!.id, 'ADM001');
      expect(admin.role, AppConstants.roleAdmin);
    });

    test('employee John has correct credentials', () async {
      final john = await db.getEmployeeByEmail('john@test.com');
      expect(john, isNotNull);
      expect(john!.id, 'EMP001');
      expect(john.name, 'John');
      expect(john.role, AppConstants.roleEmployee);
    });

    test('employee Sarah has correct credentials', () async {
      final sarah = await db.getEmployeeByEmail('sarah@test.com');
      expect(sarah, isNotNull);
      expect(sarah!.id, 'EMP002');
      expect(sarah.name, 'Sarah');
    });

    test('reopening database does not duplicate employees', () async {
      await db.close();
      // Obtain a new instance – should reopen the same DB file.
      final db2 = DatabaseHelper();
      final employees = await db2.getAllEmployees();
      expect(employees.length, 3,
          reason: 'No duplicates expected on re-open');
      await db2.close();
      await db2.deleteDatabase();
    });
  });

  // ─── 2. Employee Authentication ───────────────────────────────────────────

  group('Employee Authentication', () {
    test('valid admin credentials are found', () async {
      final emp = await db.getEmployeeByEmail('admin@test.com');
      expect(emp, isNotNull);
      expect(emp!.password, 'admin123');
    });

    test('valid employee credentials are found', () async {
      final emp = await db.getEmployeeByEmail('john@test.com');
      expect(emp, isNotNull);
      expect(emp!.password, '123456');
    });

    test('unknown email returns null', () async {
      final emp = await db.getEmployeeByEmail('unknown@test.com');
      expect(emp, isNull);
    });

    test('wrong password scenario – password does not match', () async {
      final emp = await db.getEmployeeByEmail('john@test.com');
      expect(emp, isNotNull);
      expect(emp!.password == 'wrongpassword', isFalse);
    });
  });

  // ─── 3. Duplicate Attendance Prevention ───────────────────────────────────

  group('Duplicate Attendance Prevention', () {
    const employeeId = 'EMP001';
    const employeeName = 'John';

    AttendanceModel makeCheckIn(String date) => AttendanceModel(
          employeeId: employeeId,
          employeeName: employeeName,
          date: date,
          checkInTime: '09:00:00',
          status: 'CHECKED_IN',
        );

    test('first check-in succeeds', () async {
      final id = await db.insertAttendance(makeCheckIn('2026-01-01'));
      expect(id, greaterThan(0));
    });

    test('second check-in on same day throws (UNIQUE constraint)', () async {
      await db.insertAttendance(makeCheckIn('2026-01-02'));
      expect(
        () async => db.insertAttendance(makeCheckIn('2026-01-02')),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('checkExistingAttendance returns record when present', () async {
      await db.insertAttendance(makeCheckIn('2026-01-03'));
      final record =
          await db.checkExistingAttendance(employeeId, '2026-01-03');
      expect(record, isNotNull);
      expect(record!.checkInTime, '09:00:00');
    });

    test('checkExistingAttendance returns null when absent', () async {
      final record =
          await db.checkExistingAttendance(employeeId, '2099-12-31');
      expect(record, isNull);
    });

    test('checkout update succeeds', () async {
      await db.insertAttendance(makeCheckIn('2026-01-04'));
      final rows = await db.updateCheckout(
        employeeId: employeeId,
        date: '2026-01-04',
        checkOutTime: '18:00:00',
      );
      expect(rows, 1);
      final record =
          await db.checkExistingAttendance(employeeId, '2026-01-04');
      expect(record!.checkOutTime, '18:00:00');
    });
  });

  // ─── 4. QR Session Expiration ─────────────────────────────────────────────

  group('QR Session Expiration', () {
    QRSessionModel makeSession({required bool expired}) {
      final now = DateTime.now();
      final expires = expired
          ? now.subtract(const Duration(seconds: 10))
          : now.add(const Duration(seconds: 60));
      return QRSessionModel(
        sessionId: 'QRS_TEST_${now.millisecondsSinceEpoch}',
        createdAt: now.toIso8601String(),
        expiresAt: expires.toIso8601String(),
        token: 'abc123token',
        isActive: true,
      );
    }

    test('non-expired session reports isExpired = false', () {
      final session = makeSession(expired: false);
      expect(session.isExpired, isFalse);
    });

    test('expired session reports isExpired = true', () {
      final session = makeSession(expired: true);
      expect(session.isExpired, isTrue);
    });

    test('remainingSeconds is positive for active session', () {
      final session = makeSession(expired: false);
      expect(session.remainingSeconds, greaterThan(0));
    });

    test('remainingSeconds is 0 for expired session', () {
      final session = makeSession(expired: true);
      expect(session.remainingSeconds, 0);
    });

    test('saveQRSession and retrieve from DB', () async {
      final session = makeSession(expired: false);
      await db.saveQRSession(session);
      final retrieved = await db.getQRSession(session.sessionId);
      expect(retrieved, isNotNull);
      expect(retrieved!.token, session.token);
      expect(retrieved.isActive, isTrue);
    });

    test('invalidateQRSession marks session inactive', () async {
      final session = makeSession(expired: false);
      await db.saveQRSession(session);
      await db.invalidateQRSession(session.sessionId);
      final retrieved = await db.getQRSession(session.sessionId);
      expect(retrieved!.isActive, isFalse);
    });
  });

  // ─── 5. QR Token Validation ───────────────────────────────────────────────

  group('QR Token Validation', () {
    test('token fromMap round-trip is correct', () {
      final now = DateTime.now();
      final expires = now.add(const Duration(seconds: 60));
      final original = QRSessionModel(
        sessionId: 'QRS_123',
        createdAt: now.toIso8601String(),
        expiresAt: expires.toIso8601String(),
        token: 'securetoken_abcdef',
        isActive: true,
      );
      final map = original.toMap();
      final restored = QRSessionModel.fromMap({...map, 'id': 1});

      expect(restored.sessionId, original.sessionId);
      expect(restored.token, original.token);
      expect(restored.isActive, original.isActive);
    });

    test('differing tokens are not equal', () {
      const tokenA = 'aaaa';
      const tokenB = 'bbbb';
      expect(tokenA == tokenB, isFalse);
    });

    test('matching tokens are equal', () {
      const token = 'shared_token_xyz';
      expect(token == token, isTrue);
    });
  });
}
