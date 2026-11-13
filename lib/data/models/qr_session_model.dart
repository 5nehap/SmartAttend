import 'package:equatable/equatable.dart';

class QRSessionModel extends Equatable {
  final int? id;
  final String sessionId;
  final String createdAt;
  final String expiresAt;
  final String token;
  final bool isActive;

  const QRSessionModel({
    this.id,
    required this.sessionId,
    required this.createdAt,
    required this.expiresAt,
    required this.token,
    this.isActive = true,
  });

  factory QRSessionModel.fromMap(Map<String, dynamic> map) {
    return QRSessionModel(
      id: map['id'] as int?,
      sessionId: map['sessionId'] as String,
      createdAt: map['createdAt'] as String,
      expiresAt: map['expiresAt'] as String,
      token: map['token'] as String,
      isActive: (map['isActive'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sessionId': sessionId,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'token': token,
      'isActive': isActive ? 1 : 0,
    };
  }

  QRSessionModel copyWith({
    int? id,
    String? sessionId,
    String? createdAt,
    String? expiresAt,
    String? token,
    bool? isActive,
  }) {
    return QRSessionModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      token: token ?? this.token,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Returns true if the session has not yet passed its expiry time.
  bool get isExpired {
    try {
      final expires = DateTime.parse(expiresAt);
      return DateTime.now().isAfter(expires);
    } catch (_) {
      return true;
    }
  }

  /// Remaining seconds before expiry (0 if expired).
  int get remainingSeconds {
    try {
      final expires = DateTime.parse(expiresAt);
      final diff = expires.difference(DateTime.now()).inSeconds;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  List<Object?> get props =>
      [id, sessionId, createdAt, expiresAt, token, isActive];
}
