import 'package:dio/dio.dart';

/// Mock REST API service using Dio.
/// All API calls gracefully fail and return null so SQLite operations continue.
/// Structure is ready to point at a real backend by changing [baseUrl].
class ApiService {
  static const String baseUrl = 'https://api.smartattend.local/v1';

  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => _log(obj.toString()),
      ),
    );
  }

  void _log(String message) {
    // Suppress in release; use print only during debug.
    // ignore: avoid_print
    print('[ApiService] $message');
  }

  /// Mock login. Returns employee map on success, null on failure/unavailability.
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>?;
      }
      return null;
    } on DioException {
      // Server unavailable – fall back to local SQLite.
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch all employees from the remote API.
  Future<List<Map<String, dynamic>>?> fetchEmployees() async {
    try {
      final response = await _dio.get('/employees');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
            response.data as List<dynamic>? ?? []);
      }
      return null;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Submit attendance to the remote API (best-effort; failures are non-blocking).
  Future<bool> submitAttendance(Map<String, dynamic> attendanceData) async {
    try {
      final response = await _dio.post(
        '/attendance',
        data: attendanceData,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch attendance history for a specific employee.
  Future<List<Map<String, dynamic>>?> fetchAttendanceHistory(
      String employeeId) async {
    try {
      final response = await _dio.get('/attendance/$employeeId');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
            response.data as List<dynamic>? ?? []);
      }
      return null;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
