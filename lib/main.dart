import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/di/app_dependencies.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/bloc/admin_bloc.dart';
import 'features/attendance/bloc/attendance_bloc.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/qr/bloc/qr_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = AppDependencies.create();
  runApp(SmartAttendApp(deps: deps));
}

class SmartAttendApp extends StatelessWidget {
  final AppDependencies deps;

  const SmartAttendApp({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authRepository: deps.authRepository)
            ..add(const AuthSessionCheckRequested()),
        ),
        BlocProvider<AttendanceBloc>(
          create: (_) => AttendanceBloc(
            attendanceRepository: deps.attendanceRepository,
            locationService: deps.location,
          ),
        ),
        BlocProvider<QRBloc>(
          create: (_) => QRBloc(qrRepository: deps.qrRepository),
        ),
        BlocProvider<AdminBloc>(
          create: (_) => AdminBloc(adminRepository: deps.adminRepository),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
