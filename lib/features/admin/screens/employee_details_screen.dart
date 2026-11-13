import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/employee_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/dashboard_widgets.dart';
import '../../../shared/widgets/loading_view.dart';
import '../bloc/admin_bloc.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final EmployeeModel employee;

  const EmployeeDetailsScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AdminBloc>().add(
          AdminEmployeeDetailRequested(employeeId: widget.employee.id),
        );
  }

  Future<void> _refresh() async {
    context.read<AdminBloc>().add(
          AdminEmployeeDetailRequested(employeeId: widget.employee.id),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.employee.name),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocConsumer<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AdminError) {
            AppSnackbar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is AdminLoading) {
            return const LoadingView(message: 'Loading employee details...');
          }

          if (state is AdminEmployeeDetailLoaded &&
              state.employee.id == widget.employee.id) {
            return RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: _refresh,
              child: _DetailContent(state: state),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                const Text(
                  'Could not load employee details.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Detail content ───────────────────────────────────────────────────────────

class _DetailContent extends StatelessWidget {
  final AdminEmployeeDetailLoaded state;

  const _DetailContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final emp = state.employee;
    final history = state.history;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ─── Employee profile card ───────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.primaryBlue,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          emp.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            emp.id,
                            style: TextStyle(
                                color: Colors.white.withAlpha(180),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoChip(icon: Icons.email_outlined, label: emp.email),
                const SizedBox(height: 6),
                _InfoChip(
                  icon: Icons.badge_outlined,
                  label: emp.role.toUpperCase(),
                ),
              ],
            ),
          ),
        ),

        // ─── Attendance stats ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Total\nDays',
                    value: state.totalDays.toString(),
                    icon: Icons.calendar_month_rounded,
                    iconColor: AppColors.primaryBlue,
                    iconBg: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Completed',
                    value: state.completedDays.toString(),
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.success,
                    iconBg: AppColors.successLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Pending\nCheckout',
                    value:
                        (state.totalDays - state.completedDays).toString(),
                    icon: Icons.pending_rounded,
                    iconColor: AppColors.warning,
                    iconBg: AppColors.warningLight,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── History section label ───────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Attendance History',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // ─── Empty state ─────────────────────────────────────────────
        if (history.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.event_note_outlined,
                      size: 56, color: AppColors.textTertiary),
                  SizedBox(height: 14),
                  Text(
                    'No attendance records for this employee.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          // ─── Attendance history list ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DetailAttendanceCard(record: history[i]),
                ),
                childCount: history.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withAlpha(180)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
                color: Colors.white.withAlpha(200), fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Detail attendance card ───────────────────────────────────────────────────

class _DetailAttendanceCard extends StatelessWidget {
  final AttendanceModel record;

  const _DetailAttendanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final isComplete = record.hasCheckOut;
    final statusColor = isComplete ? AppColors.success : AppColors.warning;
    final statusBg =
        isComplete ? AppColors.successLight : AppColors.warningLight;

    DateTime? parsedDate;
    try {
      parsedDate = DateFormat('yyyy-MM-dd').parse(record.date);
    } catch (_) {}

    final dayOfWeek =
        parsedDate != null ? DateFormat('EEE').format(parsedDate) : '';
    final formattedDate = parsedDate != null
        ? DateFormat('d MMM yyyy').format(parsedDate)
        : record.date;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Day-of-week block
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayOfWeek,
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  parsedDate != null
                      ? parsedDate.day.toString()
                      : '--',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _SmallChip(
                      icon: Icons.login_rounded,
                      text: record.checkInTime,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    _SmallChip(
                      icon: Icons.logout_rounded,
                      text: record.checkOutTime ?? '--:--',
                      color: isComplete
                          ? AppColors.error
                          : AppColors.textTertiary,
                    ),
                  ],
                ),
                if (record.checkInLatitude != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${record.checkInLatitude!.toStringAsFixed(4)}, '
                          '${record.checkInLongitude!.toStringAsFixed(4)}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
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
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SmallChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
