import '../../core/database/database_helper.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_service.dart';
import '../models/employee_model.dart';

class AuthRepository {
  final DatabaseHelper _db;
  final ApiService _api;
  final SessionService _session;

  AuthRepository({
    required DatabaseHelper db,
    required ApiService api,
    required SessionService session,
  })  : _db = db,
        _api = api,
        _session = session;

  /// Authenticate by email and password.
  /// First tries the remote API; falls back to local SQLite if unavailable.
  /// Returns the authenticated [EmployeeModel] or null on failure.
  Future<EmployeeModel?> login({
    required String email,
    required String password,
  }) async {
    // Attempt remote API login (non-blocking on failure).
    final apiResult = await _api.login(email: email, password: password);
    if (apiResult != null) {
      try {
        final employee = EmployeeModel.fromMap(apiResult);
        await _session.saveSession(userId: employee.id, role: employee.role);
        return employee;
      } catch (_) {
        // API returned unexpected format; fall through to local.
      }
    }

    // Local SQLite authentication.
    final employee = await _db.getEmployeeByEmail(email);
    if (employee == null) return null;
    if (employee.password != password) return null;

    await _session.saveSession(userId: employee.id, role: employee.role);
    return employee;
  }

  /// Fetch employee details by ID from local database.
  Future<EmployeeModel?> getEmployeeById(String id) async {
    return _db.getEmployeeById(id);
  }

  /// Restore session from shared_preferences if still valid.
  /// Returns the logged-in employee or null.
  Future<EmployeeModel?> restoreSession() async {
    final isLoggedIn = await _session.isLoggedIn();
    if (!isLoggedIn) return null;

    final userId = await _session.getSavedUserId();
    if (userId == null || userId.isEmpty) return null;

    return _db.getEmployeeById(userId);
  }

  /// Clear the session (logout).
  Future<void> logout() async {
    await _session.clearSession();
  }
}
