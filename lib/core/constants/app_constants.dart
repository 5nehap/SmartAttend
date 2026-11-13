class AppConstants {
  static const String appName = 'SmartAttend';
  static const String appVersion = '1.0.0';

  // QR Session Expiry
  static const int qrSessionDurationSeconds = 60;

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleEmployee = 'employee';

  // Attendance Statuses
  static const String statusPresent = 'PRESENT';
  static const String statusHalfDay = 'HALF_DAY';
  static const String statusAbsent = 'ABSENT';

  // Storage Keys
  static const String keyUserSession = 'user_session';
  static const String keyUserRole = 'user_role';
  static const String keyUserId = 'user_id';
}
