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
import '../../qr/screens/qr_scanner_screen.dart';
import '../bloc/attendance_bloc.dart';
import 'attendance_history_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  void _loadDashboard() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<AttendanceBloc>().add(
            AttendanceRefreshRequested(employeeId: authState.employee.id),
          );
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (_, curr) => curr is AuthUnauthenticated,
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      },
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) return const LoadingView();
        final employee = authState.employee;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: BlocConsumer<AttendanceBloc, AttendanceState>(
            listener: (context, state) {
              if (state is AttendanceActionSuccess) {
                AppSnackbar.showSuccess(context, state.message);
                // Refresh after action.
                context.read<AttendanceBloc>().add(
                      AttendanceRefreshRequested(employeeId: employee.id),
                    );
              } else if (state is AttendanceError) {
                AppSnackbar.showError(context, state.message);
              }
            },
            builder: (context, attendanceState) {
              final today = attendanceState is AttendanceLoaded
                  ? attendanceState.todayAttendance
                  : null;
              final history = attendanceState is AttendanceLoaded
                  ? attendanceState.history
                  : <AttendanceModel>[];
              final isLoading = attendanceState is AttendanceLoading;

              return RefreshIndicator(
                color: AppColors.primaryBlue,
                onRefresh: () async => _loadDashboard(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ─── App Bar / Header ───────────────────────────────
                    SliverAppBar(
                      expandedHeight: 170,
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
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                                        child: Center(
                                          child: Text(
                                            employee.name[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _greeting(),
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withAlpha(180),
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              employee.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _headerChip(
                                          Icons.badge_outlined, employee.id),
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

                    // ─── Body ───────────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: LoadingView(message: 'Loading attendance...'),
                            )
                          else ...[
                            _TodayAttendanceCard(today: today),
                            const SizedBox(height: 20),
                            _QuickActionsRow(employeeId: employee.id),
                            const SizedBox(height: 20),
                            _AttendanceStatsRow(history: history),
                            const SizedBox(height: 20),
                            _RecentHistorySection(history: history),
                            const SizedBox(height: 20),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
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
}

// ─── Today Attendance Card ─────────────────────────────────────────────────

class _TodayAttendanceCard extends StatelessWidget {
  final AttendanceModel? today;

  const _TodayAttendanceCard({this.today});

  @override
  Widget build(BuildContext context) {
    final hasCheckIn = today != null;
    final hasCheckOut = today?.hasCheckOut ?? false;

    String statusLabel;
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    if (!hasCheckIn) {
      statusLabel = 'Not Checked In';
      statusColor = AppColors.textSecondary;
      statusBg = AppColors.surface;
      statusIcon = Icons.access_time_rounded;
    } else if (!hasCheckOut) {
      statusLabel = 'Checked In';
      statusColor = AppColors.warning;
      statusBg = AppColors.warningLight;
      statusIcon = Icons.login_rounded;
    } else {
      statusLabel = 'Complete';
      statusColor = AppColors.success;
      statusBg = AppColors.successLight;
      statusIcon = Icons.task_alt_rounded;
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
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
              StatusBadge(
                label: statusLabel,
                color: statusColor,
                bgColor: statusBg,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _timeColumn(
                icon: Icons.login_rounded,
                label: 'Check In',
                time: today?.checkInTime ?? '--:--',
                color: AppColors.success,
              ),
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.border,
                ),
              ),
              _timeColumn(
                icon: Icons.logout_rounded,
                label: 'Check Out',
                time: today?.checkOutTime ?? '--:--',
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 15, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  _statusDescription(hasCheckIn, hasCheckOut),
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusDescription(bool hasCheckIn, bool hasCheckOut) {
    if (!hasCheckIn) return 'Scan QR code to mark your attendance';
    if (!hasCheckOut) return 'Scan QR code again to check out';
    return 'Attendance completed for today';
  }

  Widget _timeColumn({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          time,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Quick Actions ─────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  final String employeeId;

  const _QuickActionsRow({required this.employeeId});

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
                label: 'Scan\nQR Code',
                icon: Icons.qr_code_scanner_rounded,
                color: AppColors.primaryBlue,
                bgColor: AppColors.primaryLight,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const QRScannerScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                label: 'Attendance\nHistory',
                icon: Icons.history_rounded,
                color: AppColors.primaryIndigo,
                bgColor: const Color(0xFFEEF2FF),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AttendanceHistoryScreen()),
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

// ─── Stats Row ─────────────────────────────────────────────────────────────

class _AttendanceStatsRow extends StatelessWidget {
  final List<AttendanceModel> history;

  const _AttendanceStatsRow({required this.history});

  @override
  Widget build(BuildContext context) {
    final presentDays =
        history.where((r) => r.status == 'PRESENT').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Statistics',
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
                label: 'Total Days',
                value: history.length.toString(),
                icon: Icons.calendar_month_rounded,
                iconColor: AppColors.primaryBlue,
                iconBg: AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Present',
                value: presentDays.toString(),
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.success,
                iconBg: AppColors.successLight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Recent History ────────────────────────────────────────────────────────

class _RecentHistorySection extends StatelessWidget {
  final List<AttendanceModel> history;

  const _RecentHistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    final recent = history.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Attendance',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            if (history.length > 5)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AttendanceHistoryScreen()),
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
        if (recent.isEmpty)
          AppCard(
            child: Column(
              children: [
                const Icon(Icons.event_note_outlined,
                    size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 10),
                const Text(
                  'No attendance records yet.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...recent.map((r) => _AttendanceRow(record: r)),
      ],
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final AttendanceModel record;

  const _AttendanceRow({required this.record});

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
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isComplete
                    ? Icons.task_alt_rounded
                    : Icons.login_rounded,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.date,
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
              label: isComplete ? 'Present' : 'Half',
              color: statusColor,
              bgColor: statusBg,
            ),
          ],
        ),
      ),
    );
  }
}
