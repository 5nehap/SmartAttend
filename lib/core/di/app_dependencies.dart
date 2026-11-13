import '../../core/database/database_helper.dart';
import '../../core/services/api_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/session_service.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/qr_repository.dart';

/// Centralized dependency container.
/// Instantiated once at app start and passed to MultiBlocProvider.
class AppDependencies {
  final DatabaseHelper db;
  final ApiService api;
  final SessionService session;
  final LocationService location;

  final AuthRepository authRepository;
  final AttendanceRepository attendanceRepository;
  final QRRepository qrRepository;
  final AdminRepository adminRepository;

  AppDependencies._({
    required this.db,
    required this.api,
    required this.session,
    required this.location,
    required this.authRepository,
    required this.attendanceRepository,
    required this.qrRepository,
    required this.adminRepository,
  });

  factory AppDependencies.create() {
    final db = DatabaseHelper();
    final api = ApiService();
    final session = SessionService();
    final location = LocationService();

    return AppDependencies._(
      db: db,
      api: api,
      session: session,
      location: location,
      authRepository: AuthRepository(db: db, api: api, session: session),
      attendanceRepository: AttendanceRepository(db: db, api: api),
      qrRepository: QRRepository(db: db),
      adminRepository: AdminRepository(db: db),
    );
  }
}
