import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class SessionService {
  /// Save the logged-in employee's ID and role to shared preferences.
  Future<void> saveSession({
    required String userId,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserId, userId);
    await prefs.setString(AppConstants.keyUserRole, role);
    await prefs.setBool(AppConstants.keyUserSession, true);
  }

  /// Returns the saved user ID, or null if no session exists.
  Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyUserId);
  }

  /// Returns the saved user role, or null if no session exists.
  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyUserRole);
  }

  /// Returns true if a user session is currently active.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyUserSession) ?? false;
  }

  /// Clear all session data (logout).
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUserId);
    await prefs.remove(AppConstants.keyUserRole);
    await prefs.remove(AppConstants.keyUserSession);
  }
}
