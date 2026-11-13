import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/models/qr_session_model.dart';
import '../../../data/repositories/qr_repository.dart';

part 'qr_event.dart';
part 'qr_state.dart';

class QRBloc extends Bloc<QREvent, QRState> {
  final QRRepository _qrRepository;

  Timer? _countdownTimer;

  QRBloc({required QRRepository qrRepository})
      : _qrRepository = qrRepository,
        super(const QRInitial()) {
    on<QRGenerateRequested>(_onGenerateRequested);
    on<QRValidateRequested>(_onValidateRequested);
    on<QRExpireRequested>(_onExpireRequested);
    on<QRCountdownUpdated>(_onCountdownUpdated);
  }

  Future<void> _onGenerateRequested(
    QRGenerateRequested event,
    Emitter<QRState> emit,
  ) async {
    _cancelTimer();
    emit(const QRGenerating());

    try {
      final session = await _qrRepository.generateQRSession();
      final payload = _qrRepository.encodePayload(session);

      emit(QRGenerated(
        session: session,
        payload: payload,
        remainingSeconds: session.remainingSeconds,
      ));

      _startCountdown(session.sessionId);
    } catch (e) {
      emit(QRError(message: 'Failed to generate QR code: ${e.toString()}'));
    }
  }

  Future<void> _onValidateRequested(
    QRValidateRequested event,
    Emitter<QRState> emit,
  ) async {
    emit(const QRValidating());

    try {
      final result = await _qrRepository.validateQR(event.rawPayload);

      switch (result) {
        case QRValidationResult.valid:
          // Extract sessionId from payload to pass back to the caller.
          final payload = _qrRepository.decodePayload(event.rawPayload);
          final sessionId = payload?['sessionId'] as String? ?? '';
          emit(QRValidationSuccess(sessionId: sessionId));

        case QRValidationResult.expired:
          emit(const QRExpired(
              message: 'This QR code has expired. Ask admin to generate a new one.'));

        case QRValidationResult.sessionInactive:
          emit(const QRError(
              message: 'This QR code is no longer active.'));

        case QRValidationResult.invalidToken:
          emit(const QRError(
              message: 'QR code verification failed. Invalid token.'));

        case QRValidationResult.sessionNotFound:
          emit(const QRError(
              message: 'QR session not found. Please try again.'));

        case QRValidationResult.invalidFormat:
          emit(const QRError(
              message: 'Invalid QR code format. Please scan a valid SmartAttend QR.'));
      }
    } catch (e) {
      emit(QRError(message: 'QR validation error: ${e.toString()}'));
    }
  }

  Future<void> _onExpireRequested(
    QRExpireRequested event,
    Emitter<QRState> emit,
  ) async {
    _cancelTimer();
    await _qrRepository.invalidateSession(event.sessionId);
    emit(const QRExpired());
  }

  void _onCountdownUpdated(
    QRCountdownUpdated event,
    Emitter<QRState> emit,
  ) {
    final current = state;
    if (current is! QRGenerated) return;

    if (event.remainingSeconds <= 0) {
      _cancelTimer();
      // Invalidate the session in the background.
      _qrRepository.invalidateSession(current.session.sessionId);
      emit(const QRExpired());
    } else {
      emit(current.copyWithCountdown(event.remainingSeconds));
    }
  }

  void _startCountdown(String sessionId) {
    _cancelTimer();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (current is QRGenerated) {
        add(QRCountdownUpdated(remainingSeconds: current.remainingSeconds - 1));
      } else {
        _cancelTimer();
      }
    });
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  Future<void> close() {
    _cancelTimer();
    return super.close();
  }
}
