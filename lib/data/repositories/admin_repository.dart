import '../../core/database/database_helper.dart';
import '../models/attendance_model.dart';
import '../models/employee_model.dart';

class AdminRepository {
  final DatabaseHelper _db;

  AdminRepository({required DatabaseHelper db}) : _db = db;

  /// Fetch all employees (all roles).
  Future<List<EmployeeModel>> getAllEmployees() async {
    return _db.getAllEmployees();
  }

  /// Fetch a single employee by ID. Returns null if not found.
  Future<EmployeeModel?> getEmployee(String employeeId) async {
    return _db.getEmployeeById(employeeId);
  }

  /// Fetch all attendance records sorted by date descending.
  Future<List<AttendanceModel>> getAllAttendance() async {
    return _db.getAllAttendance();
  }

  /// Fetch attendance for a specific employee.
  Future<List<AttendanceModel>> getAttendanceForEmployee(
      String employeeId) async {
    return _db.getAttendanceByEmployee(employeeId);
  }

  /// Returns dashboard summary for today.
  Future<AdminDashboardSummary> getDashboardSummary() async {
    final allEmployees = await _db.getAllEmployees();
    final employees =
        allEmployees.where((e) => e.role == 'employee').toList();

    final today = _todayDate();
    final todayRecords = await _db.getAttendanceByDate(today);

    final presentIds = todayRecords.map((r) => r.employeeId).toSet();
    final presentCount = employees
        .where((e) => presentIds.contains(e.id))
        .length;
    final pendingCount = employees.length - presentCount;

    return AdminDashboardSummary(
      employees: employees,
      totalEmployees: employees.length,
      presentToday: presentCount,
      pendingToday: pendingCount,
      todayRecords: todayRecords,
    );
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class AdminDashboardSummary {
  final List<EmployeeModel> employees;
  final int totalEmployees;
  final int presentToday;
  final int pendingToday;
  final List<AttendanceModel> todayRecords;

  const AdminDashboardSummary({
    required this.employees,
    required this.totalEmployees,
    required this.presentToday,
    required this.pendingToday,
    required this.todayRecords,
  });
}

