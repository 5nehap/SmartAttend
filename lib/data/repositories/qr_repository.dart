import 'dart:convert';
import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/qr_session_model.dart';

/// Result of validating a QR code scan.
enum QRValidationResult {
  valid,
  expired,
  invalidToken,
  invalidFormat,
  sessionNotFound,
  sessionInactive,
}

/// NOTE: This is a LOCAL MOCK implementation of QR validation for assessment
/// purposes only. In production, QR payload verification MUST be performed
/// server-side. Never trust client-side payload contents alone in production.
class QRRepository {
  final DatabaseHelper _db;

  QRRepository({required DatabaseHelper db}) : _db = db;

  /// Generate a cryptographically random token (256-bit hex).
  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate a unique session ID using timestamp + random suffix.
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final suffix = Random.secure().nextInt(99999).toString().padLeft(5, '0');
    return 'QRS_${timestamp}_$suffix';
  }

  /// Create a new QR session valid for [AppConstants.qrSessionDurationSeconds].
  Future<QRSessionModel> generateQRSession() async {
    // Invalidate any previously active sessions first.
    await _db.invalidateExpiredSessions();

    final now = DateTime.now();
    final expires =
        now.add(const Duration(seconds: AppConstants.qrSessionDurationSeconds));

    final session = QRSessionModel(
      sessionId: _generateSessionId(),
      createdAt: now.toIso8601String(),
      expiresAt: expires.toIso8601String(),
      token: _generateToken(),
      isActive: true,
    );

    await _db.saveQRSession(session);
    return session;
  }

  /// Encode a QR session into a JSON string payload for the QR image.
  String encodePayload(QRSessionModel session) {
    final payload = {
      'sessionId': session.sessionId,
      'token': session.token,
      'expiresAt': session.expiresAt,
    };
    return jsonEncode(payload);
  }

  /// Decode scanned QR string into a payload map, or null if invalid JSON.
  Map<String, dynamic>? decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Validate a scanned QR payload against the local session store.
  ///
  /// LOCAL MOCK: In production move this to a secure backend endpoint.
  Future<QRValidationResult> validateQR(String rawPayload) async {
    final payload = decodePayload(rawPayload);
    if (payload == null) return QRValidationResult.invalidFormat;

    final sessionId = payload['sessionId'] as String?;
    final token = payload['token'] as String?;
    final expiresAtStr = payload['expiresAt'] as String?;

    if (sessionId == null || token == null || expiresAtStr == null) {
      return QRValidationResult.invalidFormat;
    }

    // Client-side expiry check (fast-fail before DB lookup).
    try {
      final expiresAt = DateTime.parse(expiresAtStr);
      if (DateTime.now().isAfter(expiresAt)) {
        return QRValidationResult.expired;
      }
    } catch (_) {
      return QRValidationResult.invalidFormat;
    }

    // Authoritative check from local DB (mimicking a backend lookup).
    final session = await _db.getQRSession(sessionId);
    if (session == null) return QRValidationResult.sessionNotFound;
    if (!session.isActive) return QRValidationResult.sessionInactive;
    if (session.isExpired) {
      await _db.invalidateQRSession(sessionId);
      return QRValidationResult.expired;
    }

    // Constant-time token comparison to prevent timing attacks.
    if (!_secureCompare(session.token, token)) {
      return QRValidationResult.invalidToken;
    }

    return QRValidationResult.valid;
  }

  /// Invalidate a QR session explicitly (e.g. after employee scans it).
  Future<void> invalidateSession(String sessionId) async {
    await _db.invalidateQRSession(sessionId);
  }

  /// Retrieve an active session by ID.
  Future<QRSessionModel?> getSession(String sessionId) async {
    return _db.getQRSession(sessionId);
  }

  /// Constant-time string comparison to avoid timing side-channels.
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
