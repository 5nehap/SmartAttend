import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/dashboard_widgets.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/screens/login_screen.dart';
import '../../qr/screens/qr_generator_screen.dart';
import '../bloc/admin_bloc.dart';
import 'admin_attendance_records_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AdminBloc>().add(const AdminDashboardLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, curr) => curr is AuthUnauthenticated,
      listener: (context, state) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: BlocConsumer<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminError) {
              AppSnackbar.showError(context, state.message);
            }
          },
          builder: (context, adminState) {
            final authState = context.read<AuthBloc>().state;
            final adminName =
                authState is AuthAuthenticated ? authState.employee.name : 'Admin';
            final adminId =
                authState is AuthAuthenticated ? authState.employee.id : '';

            return RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: () async {
                context.read<AdminBloc>().add(const AdminRefreshRequested());
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ─── App Bar ────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 150,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: AppColors.primaryBlue,
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.white),
                        onPressed: () {
                          context
                              .read<AuthBloc>()
                              .add(const AuthLogoutRequested());
                        },
                        tooltip: 'Logout',
                      ),
                      const SizedBox(width: 4),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryBlue,
                              AppColors.primaryIndigo
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(30),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.admin_panel_settings_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome back,',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withAlpha(180),
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          adminName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _headerChip(
                                        Icons.badge_outlined, adminId),
                                    const SizedBox(width: 10),
                                    _headerChip(
                                      Icons.calendar_today_outlined,
                                      DateFormat('EEE, d MMM y')
                                          .format(DateTime.now()),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ─── Body ────────────────────────────────────────────
                  if (adminState is AdminLoading)
                    const SliverFillRemaining(
                      child: LoadingView(message: 'Loading dashboard...'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildStats(adminState),
                          const SizedBox(height: 20),
                          _AdminQuickActionsRow(),
                          const SizedBox(height: 20),
                          _buildRecentAttendance(adminState),
                          const SizedBox(height: 20),
                        ]),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withAlpha(200)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(AdminState adminState) {
    int total = 0, present = 0, pending = 0;
    if (adminState is AdminDashboardLoaded) {
      total = adminState.totalEmployees;
      present = adminState.presentToday;
      pending = adminState.pendingToday;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Overview",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Total\nEmployees',
                value: total.toString(),
                icon: Icons.people_rounded,
                iconColor: AppColors.primaryBlue,
                iconBg: AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Present\nToday',
                value: present.toString(),
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.success,
                iconBg: AppColors.successLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Pending\nToday',
                value: pending.toString(),
                icon: Icons.pending_rounded,
                iconColor: AppColors.warning,
                iconBg: AppColors.warningLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentAttendance(AdminState adminState) {
    List<AttendanceModel> records = [];
    if (adminState is AdminDashboardLoaded) {
      records = adminState.todayRecords.take(10).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Attendance",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const AdminAttendanceRecordsScreen()),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          AppCard(
            child: Column(
              children: const [
                Icon(Icons.event_busy_rounded,
                    size: 48, color: AppColors.textTertiary),
                SizedBox(height: 10),
                Text(
                  'No attendance records for today.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Generate a QR code and ask employees to scan.',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...records.map((r) => _AdminAttendanceRow(record: r)),
      ],
    );
  }
}

class _AdminQuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                label: 'Generate\nQR Code',
                icon: Icons.qr_code_rounded,
                color: AppColors.primaryBlue,
                bgColor: AppColors.primaryLight,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const QRGeneratorScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                label: 'Attendance\nRecords',
                icon: Icons.list_alt_rounded,
                color: AppColors.primaryIndigo,
                bgColor: const Color(0xFFEEF2FF),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AdminAttendanceRecordsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminAttendanceRow extends StatelessWidget {
  final AttendanceModel record;

  const _AdminAttendanceRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final isComplete = record.hasCheckOut;
    final statusColor =
        isComplete ? AppColors.success : AppColors.warning;
    final statusBg =
        isComplete ? AppColors.successLight : AppColors.warningLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  record.employeeName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.employeeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'In: ${record.checkInTime}  •  Out: ${record.checkOutTime ?? '--:--'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: isComplete ? 'Present' : 'Half Day',
              color: statusColor,
              bgColor: statusBg,
            ),
          ],
        ),
      ),
    );
  }
}
