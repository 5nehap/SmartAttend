part of 'qr_bloc.dart';

abstract class QREvent extends Equatable {
  const QREvent();

  @override
  List<Object?> get props => [];
}

class QRGenerateRequested extends QREvent {
  const QRGenerateRequested();
}

class QRValidateRequested extends QREvent {
  final String rawPayload;

  const QRValidateRequested({required this.rawPayload});

  @override
  List<Object?> get props => [rawPayload];
}

class QRExpireRequested extends QREvent {
  final String sessionId;

  const QRExpireRequested({required this.sessionId});

  @override
  List<Object?> get props => [sessionId];
}

class QRCountdownUpdated extends QREvent {
  final int remainingSeconds;

  const QRCountdownUpdated({required this.remainingSeconds});

  @override
  List<Object?> get props => [remainingSeconds];
}
