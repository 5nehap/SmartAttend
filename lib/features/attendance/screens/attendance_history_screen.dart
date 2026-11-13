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
import '../bloc/attendance_bloc.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  // Filter: null = all, 'PRESENT' = completed, 'CHECKED_IN' = pending
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<AttendanceBloc>().add(
            AttendanceLoadHistory(employeeId: authState.employee.id),
          );
    }
  }

  Future<void> _refresh(String employeeId) async {
    context
        .read<AttendanceBloc>()
        .add(AttendanceLoadHistory(employeeId: employeeId));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final employee =
        authState is AuthAuthenticated ? authState.employee : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Filter button
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            tooltip: 'Filter by status',
            onSelected: (value) {
              setState(() => _statusFilter = value);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Records'),
              ),
              const PopupMenuItem(
                value: 'PRESENT',
                child: Text('Completed'),
              ),
              const PopupMenuItem(
                value: 'CHECKED_IN',
                child: Text('Pending Checkout'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: employee != null ? () => _refresh(employee.id) : null,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocConsumer<AttendanceBloc, AttendanceState>(
        listener: (context, state) {
          if (state is AttendanceError) {
            AppSnackbar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is AttendanceLoading) {
            return const LoadingView(message: 'Loading history...');
          }

          if (state is AttendanceLoaded) {
            return RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: () async {
                if (employee != null) await _refresh(employee.id);
              },
              child: _HistoryContent(
                employee: employee,
                history: state.history,
                statusFilter: _statusFilter,
              ),
            );
          }

          // Initial or error — show refresh prompt.
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_note_outlined,
                    size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                const Text(
                  'Could not load attendance history.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: employee != null
                      ? () => _refresh(employee.id)
                      : null,
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

// ─── History content (summary + list) ─────────────────────────────────────────

class _HistoryContent extends StatelessWidget {
  final dynamic employee;
  final List<AttendanceModel> history;
  final String? statusFilter;

  const _HistoryContent({
    required this.employee,
    required this.history,
    required this.statusFilter,
  });

  @override
  Widget build(BuildContext context) {
    final total = history.length;
    final completed = history.where((r) => r.hasCheckOut).length;
    final pending = total - completed;

    // Apply filter
    final filtered = statusFilter == null
        ? history
        : history.where((r) {
            if (statusFilter == 'PRESENT') return r.hasCheckOut;
            if (statusFilter == 'CHECKED_IN') return !r.hasCheckOut;
            return true;
          }).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ─── Employee header ────────────────────────────────────────
        if (employee != null)
          SliverToBoxAdapter(
            child: _EmployeeHeader(employee: employee),
          ),

        // ─── Summary cards ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _SummaryRow(
              total: total,
              completed: completed,
              pending: pending,
            ),
          ),
        ),

        // ─── Filter chip (shows active filter) ──────────────────────
        if (statusFilter != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 14, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Text(
                    'Showing: ${statusFilter == 'PRESENT' ? 'Completed' : 'Pending Checkout'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ─── Section label ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              filtered.isEmpty
                  ? ''
                  : '${filtered.length} Record${filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // ─── Empty state ─────────────────────────────────────────────
        if (filtered.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_outlined,
                      size: 64, color: AppColors.textTertiary),
                  SizedBox(height: 16),
                  Text(
                    'No attendance records found.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Scan the attendance QR to record your attendance.',
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          // ─── History list ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HistoryCard(record: filtered[i]),
                ),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Employee header strip ─────────────────────────────────────────────────────

class _EmployeeHeader extends StatelessWidget {
  final dynamic employee;

  const _EmployeeHeader({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryBlue,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                employee.id,
                style: TextStyle(
                    color: Colors.white.withAlpha(180), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Summary row ────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int total;
  final int completed;
  final int pending;

  const _SummaryRow({
    required this.total,
    required this.completed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Total\nDays',
            value: total.toString(),
            icon: Icons.calendar_month_rounded,
            iconColor: AppColors.primaryBlue,
            iconBg: AppColors.primaryLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'Completed',
            value: completed.toString(),
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.success,
            iconBg: AppColors.successLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'Pending\nCheckout',
            value: pending.toString(),
            icon: Icons.pending_rounded,
            iconColor: AppColors.warning,
            iconBg: AppColors.warningLight,
          ),
        ),
      ],
    );
  }
}

// ─── History card ────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final AttendanceModel record;

  const _HistoryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final isComplete = record.hasCheckOut;
    final statusColor = isComplete ? AppColors.success : AppColors.warning;
    final statusBg =
        isComplete ? AppColors.successLight : AppColors.warningLight;
    final statusLabel = isComplete ? 'Completed' : 'Pending Checkout';

    // Parse the date for display.
    DateTime? parsedDate;
    try {
      parsedDate = DateFormat('yyyy-MM-dd').parse(record.date);
    } catch (_) {}

    final dayOfWeek =
        parsedDate != null ? DateFormat('EEEE').format(parsedDate) : '';
    final formattedDate = parsedDate != null
        ? DateFormat('d MMM yyyy').format(parsedDate)
        : record.date;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Date + status badge ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (dayOfWeek.isNotEmpty)
                    Text(
                      dayOfWeek,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              StatusBadge(
                label: statusLabel,
                color: statusColor,
                bgColor: statusBg,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Check-in / Check-out chips ──────────────────────────
          Row(
            children: [
              _TimeChip(
                icon: Icons.login_rounded,
                label: 'In',
                time: record.checkInTime,
                color: AppColors.success,
              ),
              const SizedBox(width: 10),
              _TimeChip(
                icon: Icons.logout_rounded,
                label: 'Out',
                time: record.checkOutTime ?? '--:--',
                color: record.hasCheckOut
                    ? AppColors.error
                    : AppColors.textTertiary,
              ),
            ],
          ),

          // ─── Location row ────────────────────────────────────────
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _locationText(record),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _locationText(AttendanceModel r) {
    if (r.checkInLatitude == null || r.checkInLongitude == null) {
      return 'Location unavailable';
    }
    return 'Check-in: ${r.checkInLatitude!.toStringAsFixed(4)}, '
        '${r.checkInLongitude!.toStringAsFixed(4)}';
  }
}

// ─── Time chip widget ────────────────────────────────────────────────────────

class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  const _TimeChip({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: $time',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
