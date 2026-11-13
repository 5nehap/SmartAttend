part of 'qr_bloc.dart';

abstract class QRState extends Equatable {
  const QRState();

  @override
  List<Object?> get props => [];
}

class QRInitial extends QRState {
  const QRInitial();
}

class QRGenerating extends QRState {
  const QRGenerating();
}

class QRGenerated extends QRState {
  final QRSessionModel session;
  final String payload;
  final int remainingSeconds;

  const QRGenerated({
    required this.session,
    required this.payload,
    required this.remainingSeconds,
  });

  QRGenerated copyWithCountdown(int remaining) => QRGenerated(
        session: session,
        payload: payload,
        remainingSeconds: remaining,
      );

  @override
  List<Object?> get props => [session, payload, remainingSeconds];
}

class QRValidating extends QRState {
  const QRValidating();
}

class QRValidationSuccess extends QRState {
  final String sessionId;

  const QRValidationSuccess({required this.sessionId});

  @override
  List<Object?> get props => [sessionId];
}

class QRExpired extends QRState {
  final String message;

  const QRExpired({this.message = 'QR code has expired. Please request a new one.'});

  @override
  List<Object?> get props => [message];
}

class QRError extends QRState {
  final String message;

  const QRError({required this.message});

  @override
  List<Object?> get props => [message];
}
