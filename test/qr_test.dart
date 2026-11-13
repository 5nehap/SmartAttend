import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartattend/core/database/database_helper.dart';
import 'package:smartattend/core/services/api_service.dart';
import 'package:smartattend/core/services/location_service.dart';
import 'package:smartattend/data/models/attendance_model.dart';
import 'package:smartattend/data/models/qr_session_model.dart';
import 'package:smartattend/data/repositories/attendance_repository.dart';
import 'package:smartattend/data/repositories/qr_repository.dart';
import 'package:smartattend/features/attendance/bloc/attendance_bloc.dart';
import 'package:smartattend/features/qr/bloc/qr_bloc.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late QRRepository qrRepo;
  late AttendanceRepository attendanceRepo;

  setUp(() {
    db = DatabaseHelper();
    qrRepo = QRRepository(db: db);
    attendanceRepo = AttendanceRepository(db: db, api: ApiService());
  });

  tearDown(() async {
    await db.close();
    await db.deleteDatabase();
  });

  // ─── QR Generation ────────────────────────────────────────────────────────

  group('QR Generation', () {
    test('generates unique session IDs on each call', () async {
      final s1 = await qrRepo.generateQRSession();
      final s2 = await qrRepo.generateQRSession();
      expect(s1.sessionId, isNot(equals(s2.sessionId)));
    });

    test('token is non-empty and 64 hex chars (256-bit)', () async {
      final session = await qrRepo.generateQRSession();
      expect(session.token.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(session.token), isTrue);
    });

    test('session expires in 60 seconds', () async {
      final before = DateTime.now();
      final session = await qrRepo.generateQRSession();
      final expires = DateTime.parse(session.expiresAt);
      final diff = expires.difference(before).inSeconds;
      expect(diff, greaterThanOrEqualTo(58)); // Allow small timing jitter.
      expect(diff, lessThanOrEqualTo(62));
    });

    test('encoded payload contains required fields', () async {
      final session = await qrRepo.generateQRSession();
      final payload = qrRepo.encodePayload(session);
      final map = jsonDecode(payload) as Map<String, dynamic>;

      expect(map.containsKey('sessionId'), isTrue);
      expect(map.containsKey('token'), isTrue);
      expect(map.containsKey('expiresAt'), isTrue);
      expect(map['sessionId'], session.sessionId);
      expect(map['token'], session.token);
    });

    test('new session is marked active in DB', () async {
      final session = await qrRepo.generateQRSession();
      final stored = await db.getQRSession(session.sessionId);
      expect(stored, isNotNull);
      expect(stored!.isActive, isTrue);
    });
  });

  // ─── QR Validation ────────────────────────────────────────────────────────

  group('QR Validation', () {
    test('valid QR is accepted', () async {
      final session = await qrRepo.generateQRSession();
      final payload = qrRepo.encodePayload(session);
      final result = await qrRepo.validateQR(payload);
      expect(result, QRValidationResult.valid);
    });

    test('invalid JSON format is rejected', () async {
      final result = await qrRepo.validateQR('not-valid-json');
      expect(result, QRValidationResult.invalidFormat);
    });

    test('missing sessionId is rejected', () async {
      final payload = jsonEncode({
        'token': 'sometoken',
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 60))
            .toIso8601String(),
      });
      final result = await qrRepo.validateQR(payload);
      expect(result, QRValidationResult.invalidFormat);
    });

    test('unknown session ID returns sessionNotFound', () async {
      final payload = jsonEncode({
        'sessionId': 'QRS_UNKNOWN_12345',
        'token': 'sometoken',
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 60))
            .toIso8601String(),
      });
      final result = await qrRepo.validateQR(payload);
      expect(result, QRValidationResult.sessionNotFound);
    });

    test('wrong token is rejected', () async {
      final session = await qrRepo.generateQRSession();
      // Build payload with wrong token.
      final payload = jsonEncode({
        'sessionId': session.sessionId,
        'token': 'wrongtokenwrongtokenwrongtokenwrongtoken00000000000000000000000000',
        'expiresAt': session.expiresAt,
      });
      final result = await qrRepo.validateQR(payload);
      expect(result, QRValidationResult.invalidToken);
    });

    test('expired QR is rejected', () async {
      final now = DateTime.now();
      final expiredSession = QRSessionModel(
        sessionId: 'QRS_EXP_TEST',
        createdAt: now.subtract(const Duration(seconds: 90)).toIso8601String(),
        expiresAt: now.subtract(const Duration(seconds: 30)).toIso8601String(),
        token: 'expiredtoken',
        isActive: true,
      );
      await db.saveQRSession(expiredSession);

      final payload = jsonEncode({
        'sessionId': expiredSession.sessionId,
        'token': expiredSession.token,
        'expiresAt': expiredSession.expiresAt,
      });

      final result = await qrRepo.validateQR(payload);
      expect(result, QRValidationResult.expired);
    });

    test('invalidated session is rejected', () async {
      final session = await qrRepo.generateQRSession();
      await qrRepo.invalidateSession(session.sessionId);

      final payload = qrRepo.encodePayload(session);
      final result = await qrRepo.validateQR(payload);
      expect(result, QRValidationResult.sessionInactive);
    });
  });

  // ─── Attendance via QR scan ────────────────────────────────────────────

  group('Attendance from QR scan', () {
    late AttendanceBloc bloc;

    setUp(() {
      bloc = AttendanceBloc(
        attendanceRepository: attendanceRepo,
        locationService: LocationService(),
      );
    });

    tearDown(() => bloc.close());

    test('first scan marks check-in', () async {
      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AttendanceMarkFromQRRequested(
        employeeId: 'EMP001',
        employeeName: 'John',
      ));

      await Future.delayed(const Duration(milliseconds: 600));
      await sub.cancel();

      expect(states.last, isA<AttendanceActionSuccess>());
      final success = states.last as AttendanceActionSuccess;
      expect(success.isCheckIn, isTrue);
    });

    test('second scan marks check-out', () async {
      // First: check-in.
      bloc.add(const AttendanceMarkFromQRRequested(
        employeeId: 'EMP001',
        employeeName: 'John',
      ));
      await Future.delayed(const Duration(milliseconds: 600));

      // Second: check-out.
      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AttendanceMarkFromQRRequested(
        employeeId: 'EMP001',
        employeeName: 'John',
      ));

      await Future.delayed(const Duration(milliseconds: 600));
      await sub.cancel();

      expect(states.last, isA<AttendanceActionSuccess>());
      final success = states.last as AttendanceActionSuccess;
      expect(success.isCheckIn, isFalse);
    });

    test('third scan is rejected (attendance already complete)', () async {
      // Check-in.
      bloc.add(const AttendanceMarkFromQRRequested(
          employeeId: 'EMP001', employeeName: 'John'));
      await Future.delayed(const Duration(milliseconds: 600));

      // Check-out.
      bloc.add(const AttendanceMarkFromQRRequested(
          employeeId: 'EMP001', employeeName: 'John'));
      await Future.delayed(const Duration(milliseconds: 600));

      // Third attempt.
      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AttendanceMarkFromQRRequested(
          employeeId: 'EMP001', employeeName: 'John'));

      await Future.delayed(const Duration(milliseconds: 600));
      await sub.cancel();

      expect(states.last, isA<AttendanceError>());
      final err = states.last as AttendanceError;
      expect(err.message, contains('already complete'));
    });

    test('duplicate check-in on the same day is prevented by DB', () async {
      // Manual insert to simulate existing check-in.
      final today = DateTime.now();
      final date =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await db.insertAttendance(AttendanceModel(
        employeeId: 'EMP002',
        employeeName: 'Sarah',
        date: date,
        checkInTime: '08:00:00',
        status: 'CHECKED_IN',
      ));

      // Second check-in attempt for same employee same day.
      final states = <AttendanceState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AttendanceMarkFromQRRequested(
          employeeId: 'EMP002', employeeName: 'Sarah'));

      await Future.delayed(const Duration(milliseconds: 600));
      await sub.cancel();

      // Should be a check-out (since check-in already exists but no check-out).
      expect(states.last, isA<AttendanceActionSuccess>());
      final success = states.last as AttendanceActionSuccess;
      expect(success.isCheckIn, isFalse);
    });
  });

  // ─── QRBloc ───────────────────────────────────────────────────────────────

  group('QRBloc integration', () {
    late QRBloc qrBloc;

    setUp(() {
      qrBloc = QRBloc(qrRepository: qrRepo);
    });

    tearDown(() => qrBloc.close());

    test('generate emits QRGenerated with 60s countdown', () async {
      final states = <QRState>[];
      final sub = qrBloc.stream.listen(states.add);

      qrBloc.add(const QRGenerateRequested());
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, isA<QRGenerated>());
      final gen = states.last as QRGenerated;
      expect(gen.remainingSeconds, greaterThan(55));
      expect(gen.payload, isNotEmpty);
    });

    test('validate valid QR emits QRValidationSuccess', () async {
      qrBloc.add(const QRGenerateRequested());
      await Future.delayed(const Duration(milliseconds: 400));

      final generated = qrBloc.state as QRGenerated;

      final states = <QRState>[];
      final sub = qrBloc.stream.listen(states.add);

      qrBloc.add(QRValidateRequested(rawPayload: generated.payload));
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, isA<QRValidationSuccess>());
    });

    test('validate tampered QR emits QRError', () async {
      qrBloc.add(const QRGenerateRequested());
      await Future.delayed(const Duration(milliseconds: 400));

      final generated = qrBloc.state as QRGenerated;
      final badPayload = generated.payload.replaceFirst(
          generated.session.token.substring(0, 6), 'aaaaaa');

      final states = <QRState>[];
      final sub = qrBloc.stream.listen(states.add);

      qrBloc.add(QRValidateRequested(rawPayload: badPayload));
      await Future.delayed(const Duration(milliseconds: 400));
      await sub.cancel();

      expect(states.last, anyOf(isA<QRError>(), isA<QRExpired>()));
    });
  });
}
