import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../attendance/screens/employee_dashboard_screen.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            ),
          );
    }
  }

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
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Logo
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.primaryIndigo
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3F2563EB),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Welcome back! Sign in to continue.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email Field
                  Text(
                    'Email Address',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email address is required';
                      }
                      if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$')
                          .hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  Text(
                    'Password',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(context),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon:
                          const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        onPressed: () {
                          // Using StatefulWidget setState only for local
                          // password visibility — no business logic involved.
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Password is required';
                      }
                      if (value.trim().length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Bloc error message
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (prev, curr) =>
                        curr is AuthError || curr is AuthLoading,
                    builder: (context, state) {
                      if (state is AuthError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.error.withAlpha(80)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.message,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 28),

                  // Login button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return AppButton(
                        label: 'Sign In',
                        isLoading: state is AuthLoading,
                        onPressed: () => _login(context),
                        icon: Icons.login_rounded,
                      );
                    },
                  ),

                  const SizedBox(height: 36),
                  const _DemoCredentialsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Demo credentials section — clicking pre-fills the login form via BLoC-agnostic callbacks.
class _DemoCredentialsSection extends StatelessWidget {
  const _DemoCredentialsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Demo Credentials',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 14),
        _CredentialTile(
          role: 'Admin',
          email: 'admin@test.com',
          password: 'admin123',
          icon: Icons.admin_panel_settings_rounded,
          iconColor: AppColors.primaryBlue,
          iconBg: AppColors.primaryLight,
        ),
        const SizedBox(height: 8),
        _CredentialTile(
          role: 'Employee (John)',
          email: 'john@test.com',
          password: '123456',
          icon: Icons.person_rounded,
          iconColor: AppColors.success,
          iconBg: AppColors.successLight,
        ),
        const SizedBox(height: 8),
        _CredentialTile(
          role: 'Employee (Sarah)',
          email: 'sarah@test.com',
          password: '123456',
          icon: Icons.person_rounded,
          iconColor: AppColors.warning,
          iconBg: AppColors.warningLight,
        ),
      ],
    );
  }
}

class _CredentialTile extends StatelessWidget {
  final String role;
  final String email;
  final String password;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _CredentialTile({
    required this.role,
    required this.email,
    required this.password,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dispatch directly — no setState needed.
        context.read<AuthBloc>().add(
              AuthLoginRequested(email: email, password: password),
            );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$email  •  $password',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
