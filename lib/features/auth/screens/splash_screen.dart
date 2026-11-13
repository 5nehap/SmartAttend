import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../attendance/screens/employee_dashboard_screen.dart';
import '../bloc/auth_bloc.dart';
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          final isAdmin = state.employee.role == AppConstants.roleAdmin;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => isAdmin
                  ? const AdminDashboardScreen()
                  : const EmployeeDashboardScreen(),
            ),
          );
        } else if (state is AuthUnauthenticated || state is AuthError) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryBlue,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo container
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: Colors.white.withAlpha(60), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart QR Attendance Management',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(200),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 56),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
