import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/services/location_service.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/repositories/attendance_repository.dart';

part 'attendance_event.dart';
part 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final AttendanceRepository _attendanceRepository;
  final LocationService _locationService;

  AttendanceBloc({
    required AttendanceRepository attendanceRepository,
    required LocationService locationService,
  })  : _attendanceRepository = attendanceRepository,
        _locationService = locationService,
        super(const AttendanceInitial()) {
    on<AttendanceLoadToday>(_onLoadToday);
    on<AttendanceLoadHistory>(_onLoadHistory);
    on<AttendanceCheckInRequested>(_onCheckIn);
    on<AttendanceCheckOutRequested>(_onCheckOut);
    on<AttendanceRefreshRequested>(_onRefresh);
    on<AttendanceMarkFromQRRequested>(_onMarkFromQR);
  }

  Future<void> _onLoadToday(
    AttendanceLoadToday event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(const AttendanceLoading());
    try {
      final today = await _attendanceRepository.getTodayAttendance(event.employeeId);
      emit(AttendanceLoaded(todayAttendance: today));
    } catch (e) {
      emit(AttendanceError(message: 'Failed to load attendance: ${e.toString()}'));
    }
  }

  Future<void> _onLoadHistory(
    AttendanceLoadHistory event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(const AttendanceLoading());
    try {
      final history = await _attendanceRepository.getEmployeeHistory(event.employeeId);
      emit(AttendanceLoaded(history: history));
    } catch (e) {
      emit(AttendanceError(message: 'Failed to load history: ${e.toString()}'));
    }
  }

  Future<void> _onCheckIn(
    AttendanceCheckInRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(const AttendanceActionLoading(message: 'Recording check-in...'));

    // Capture location (never blocks attendance on failure).
    final coords = await _locationService.getCoordinates();
    final locationNote = (coords.latitude == null)
        ? ' (location unavailable)'
        : '';

    final result = await _attendanceRepository.markAttendance(
      employeeId: event.employeeId,
      employeeName: event.employeeName,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );

    switch (result) {
      case AttendanceResult.checkInSuccess:
        final record =
            await _attendanceRepository.getTodayAttendance(event.employeeId);
        emit(AttendanceActionSuccess(
          message: 'Check-in recorded successfully$locationNote.',
          updatedRecord: record,
          isCheckIn: true,
        ));

      case AttendanceResult.checkOutSuccess:
        // Should not reach here from check-in event, but handle defensively.
        final record =
            await _attendanceRepository.getTodayAttendance(event.employeeId);
        emit(AttendanceActionSuccess(
          message: 'Check-out recorded$locationNote.',
          updatedRecord: record,
          isCheckIn: false,
        ));

      case AttendanceResult.alreadyComplete:
        emit(const AttendanceError(
          message: 'Attendance is already complete for today.',
        ));

      case AttendanceResult.error:
        emit(const AttendanceError(
          message: 'Failed to record attendance. Please try again.',
        ));
    }
  }

  Future<void> _onCheckOut(
    AttendanceCheckOutRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    // Verify check-in exists before attempting check-out.
    final today = await _attendanceRepository.getTodayAttendance(event.employeeId);
    if (today == null) {
      emit(const AttendanceError(
        message: 'No check-in found for today. Please check in first.',
      ));
      return;
    }
    if (today.hasCheckOut) {
      emit(const AttendanceError(
        message: 'You have already checked out for today.',
      ));
      return;
    }

    emit(const AttendanceActionLoading(message: 'Recording check-out...'));

    final coords = await _locationService.getCoordinates();
    final locationNote = (coords.latitude == null)
        ? ' (location unavailable)'
        : '';

    final result = await _attendanceRepository.markAttendance(
      employeeId: event.employeeId,
      employeeName: event.employeeName,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );

    switch (result) {
      case AttendanceResult.checkOutSuccess:
        final record =
            await _attendanceRepository.getTodayAttendance(event.employeeId);
        emit(AttendanceActionSuccess(
          message: 'Check-out recorded successfully$locationNote.',
          updatedRecord: record,
          isCheckIn: false,
        ));

      case AttendanceResult.alreadyComplete:
        emit(const AttendanceError(
          message: 'You have already checked out for today.',
        ));

      case AttendanceResult.checkInSuccess:
        emit(const AttendanceError(
          message: 'Unexpected state: check-in recorded instead of check-out.',
        ));

      case AttendanceResult.error:
        emit(const AttendanceError(
          message: 'Failed to record check-out. Please try again.',
        ));
    }
  }

  Future<void> _onRefresh(
    AttendanceRefreshRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      final today =
          await _attendanceRepository.getTodayAttendance(event.employeeId);
      final history =
          await _attendanceRepository.getEmployeeHistory(event.employeeId);
      emit(AttendanceLoaded(todayAttendance: today, history: history));
    } catch (e) {
      emit(AttendanceError(message: 'Refresh failed: ${e.toString()}'));
    }
  }

  /// Called after a successful QR scan. Auto-determines check-in vs check-out.
  Future<void> _onMarkFromQR(
    AttendanceMarkFromQRRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(const AttendanceActionLoading(message: 'Recording attendance...'));

    final coords = await _locationService.getCoordinates();
    final locationNote =
        (coords.latitude == null) ? ' (location unavailable)' : '';

    final result = await _attendanceRepository.markAttendance(
      employeeId: event.employeeId,
      employeeName: event.employeeName,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );

    switch (result) {
      case AttendanceResult.checkInSuccess:
        final record = await _attendanceRepository
            .getTodayAttendance(event.employeeId);
        emit(AttendanceActionSuccess(
          message: 'Check-in recorded successfully$locationNote.',
          updatedRecord: record,
          isCheckIn: true,
        ));

      case AttendanceResult.checkOutSuccess:
        final record = await _attendanceRepository
            .getTodayAttendance(event.employeeId);
        emit(AttendanceActionSuccess(
          message: 'Check-out recorded successfully$locationNote.',
          updatedRecord: record,
          isCheckIn: false,
        ));

      case AttendanceResult.alreadyComplete:
        emit(const AttendanceError(
          message: 'Attendance is already complete for today.',
        ));

      case AttendanceResult.error:
        emit(const AttendanceError(
          message: 'Failed to record attendance. Please try again.',
        ));
    }
  }
}
