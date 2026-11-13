import 'package:intl/intl.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/api_service.dart';
import '../models/attendance_model.dart';

enum AttendanceResult {
  checkInSuccess,
  checkOutSuccess,
  alreadyComplete,
  error,
}

class AttendanceRepository {
  final DatabaseHelper _db;
  final ApiService _api;

  AttendanceRepository({
    required DatabaseHelper db,
    required ApiService api,
  })  : _db = db,
        _api = api;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _now => DateFormat('HH:mm:ss').format(DateTime.now());

  /// Marks check-in or check-out for an employee based on today's existing record.
  /// Returns [AttendanceResult] describing what happened.
  Future<AttendanceResult> markAttendance({
    required String employeeId,
    required String employeeName,
    double? latitude,
    double? longitude,
  }) async {
    final existing = await _db.checkExistingAttendance(employeeId, _today);

    if (existing == null) {
      // No record today → check-in
      final attendance = AttendanceModel(
        employeeId: employeeId,
        employeeName: employeeName,
        date: _today,
        checkInTime: _now,
        checkInLatitude: latitude,
        checkInLongitude: longitude,
        status: 'CHECKED_IN',
      );

      try {
        await _db.insertAttendance(attendance);
        // Best-effort API sync.
        _api.submitAttendance(attendance.toMap());
        return AttendanceResult.checkInSuccess;
      } catch (_) {
        return AttendanceResult.error;
      }
    } else if (!existing.hasCheckOut) {
      // Check-in exists, no check-out → check-out
      try {
        await _db.updateCheckout(
          employeeId: employeeId,
          date: _today,
          checkOutTime: _now,
          checkOutLatitude: latitude,
          checkOutLongitude: longitude,
        );
        // Best-effort API sync.
        final updated = existing.copyWith(
          checkOutTime: _now,
          checkOutLatitude: latitude,
          checkOutLongitude: longitude,
          status: 'PRESENT',
        );
        _api.submitAttendance(updated.toMap());
        return AttendanceResult.checkOutSuccess;
      } catch (_) {
        return AttendanceResult.error;
      }
    } else {
      // Both check-in and check-out exist.
      return AttendanceResult.alreadyComplete;
    }
  }

  /// Fetch today's attendance for an employee.
  Future<AttendanceModel?> getTodayAttendance(String employeeId) async {
    return _db.getTodayAttendance(employeeId);
  }

  /// Fetch full attendance history for an employee.
  Future<List<AttendanceModel>> getEmployeeHistory(String employeeId) async {
    return _db.getAttendanceByEmployee(employeeId);
  }

  /// Fetch all attendance records (admin).
  Future<List<AttendanceModel>> getAllAttendance() async {
    return _db.getAllAttendance();
  }

  /// Fetch all attendance records for today (admin).
  Future<List<AttendanceModel>> getTodayAllAttendance() async {
    return _db.getAttendanceByDate(_today);
  }
}
