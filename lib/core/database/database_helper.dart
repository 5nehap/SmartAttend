import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../data/models/attendance_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/qr_session_model.dart';

class DatabaseHelper {
  static const String _databaseName = 'smart_attend.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tableEmployees = 'employees';
  static const String tableAttendance = 'attendance';
  static const String tableQRSessions = 'qr_sessions';

  // Singleton
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableEmployees (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableAttendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId TEXT NOT NULL,
        employeeName TEXT NOT NULL,
        date TEXT NOT NULL,
        checkInTime TEXT NOT NULL,
        checkOutTime TEXT,
        checkInLatitude REAL,
        checkInLongitude REAL,
        checkOutLatitude REAL,
        checkOutLongitude REAL,
        status TEXT NOT NULL,
        UNIQUE(employeeId, date),
        FOREIGN KEY (employeeId) REFERENCES $tableEmployees(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableQRSessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL UNIQUE,
        createdAt TEXT NOT NULL,
        expiresAt TEXT NOT NULL,
        token TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Indexes for performance
    await db.execute(
        'CREATE INDEX idx_attendance_employee ON $tableAttendance(employeeId)');
    await db.execute(
        'CREATE INDEX idx_attendance_date ON $tableAttendance(date)');
    await db.execute(
        'CREATE INDEX idx_qr_session ON $tableQRSessions(sessionId)');

    // Seed initial employee data
    await _seedEmployees(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reserved for future migrations
  }

  /// Insert dummy employees on first run; use INSERT OR IGNORE to avoid duplicates.
  Future<void> _seedEmployees(Database db) async {
    final employees = [
      {
        'id': 'ADM001',
        'name': 'Admin',
        'email': 'admin@test.com',
        'password': 'admin123',
        'role': 'admin',
      },
      {
        'id': 'EMP001',
        'name': 'John',
        'email': 'john@test.com',
        'password': '123456',
        'role': 'employee',
      },
      {
        'id': 'EMP002',
        'name': 'Sarah',
        'email': 'sarah@test.com',
        'password': '123456',
        'role': 'employee',
      },
    ];

    final batch = db.batch();
    for (final emp in employees) {
      batch.insert(
        tableEmployees,
        emp,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ─── Employee Methods ─────────────────────────────────────────────────────

  Future<List<EmployeeModel>> getAllEmployees() async {
    final db = await database;
    final rows = await db.query(tableEmployees);
    return rows.map(EmployeeModel.fromMap).toList();
  }

  Future<EmployeeModel?> getEmployeeByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      tableEmployees,
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EmployeeModel.fromMap(rows.first);
  }

  Future<EmployeeModel?> getEmployeeById(String id) async {
    final db = await database;
    final rows = await db.query(
      tableEmployees,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EmployeeModel.fromMap(rows.first);
  }

  // ─── Attendance Methods ───────────────────────────────────────────────────

  /// Insert a new check-in record. Throws if a record for the same employee+date exists.
  Future<int> insertAttendance(AttendanceModel attendance) async {
    final db = await database;
    return db.insert(
      tableAttendance,
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Update the checkout time and coordinates for an existing attendance record.
  Future<int> updateCheckout({
    required String employeeId,
    required String date,
    required String checkOutTime,
    double? checkOutLatitude,
    double? checkOutLongitude,
  }) async {
    final db = await database;
    return db.update(
      tableAttendance,
      {
        'checkOutTime': checkOutTime,
        'checkOutLatitude': checkOutLatitude,
        'checkOutLongitude': checkOutLongitude,
        'status': 'PRESENT',
      },
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
  }

  Future<List<AttendanceModel>> getAttendanceByEmployee(
      String employeeId) async {
    final db = await database;
    final rows = await db.query(
      tableAttendance,
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'date DESC',
    );
    return rows.map(AttendanceModel.fromMap).toList();
  }

  Future<List<AttendanceModel>> getAllAttendance() async {
    final db = await database;
    final rows = await db.query(
      tableAttendance,
      orderBy: 'date DESC, checkInTime DESC',
    );
    return rows.map(AttendanceModel.fromMap).toList();
  }

  Future<AttendanceModel?> getTodayAttendance(String employeeId) async {
    final db = await database;
    final today = _todayDate();
    final rows = await db.query(
      tableAttendance,
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, today],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AttendanceModel.fromMap(rows.first);
  }

  /// Returns the existing attendance record for employee on a given date, or null.
  Future<AttendanceModel?> checkExistingAttendance(
      String employeeId, String date) async {
    final db = await database;
    final rows = await db.query(
      tableAttendance,
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AttendanceModel.fromMap(rows.first);
  }

  Future<List<AttendanceModel>> getAttendanceByDate(String date) async {
    final db = await database;
    final rows = await db.query(
      tableAttendance,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'checkInTime DESC',
    );
    return rows.map(AttendanceModel.fromMap).toList();
  }

  // ─── QR Session Methods ───────────────────────────────────────────────────

  Future<int> saveQRSession(QRSessionModel session) async {
    final db = await database;
    return db.insert(
      tableQRSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<QRSessionModel?> getQRSession(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      tableQRSessions,
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return QRSessionModel.fromMap(rows.first);
  }

  Future<int> invalidateQRSession(String sessionId) async {
    final db = await database;
    return db.update(
      tableQRSessions,
      {'isActive': 0},
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> invalidateExpiredSessions() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      tableQRSessions,
      {'isActive': 0},
      where: 'expiresAt <= ? AND isActive = 1',
      whereArgs: [now],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Close the database connection. Use in tests only.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Delete the database. Use for testing/reset only.
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
