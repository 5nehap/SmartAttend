import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/employee_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/dashboard_widgets.dart';
import '../../../shared/widgets/loading_view.dart';
import '../bloc/admin_bloc.dart';
import 'employee_details_screen.dart';

class AdminAttendanceRecordsScreen extends StatefulWidget {
  const AdminAttendanceRecordsScreen({super.key});

  @override
  State<AdminAttendanceRecordsScreen> createState() =>
      _AdminAttendanceRecordsScreenState();
}

class _AdminAttendanceRecordsScreenState
    extends State<AdminAttendanceRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // null = all, 'present' = checked in/out, 'pending' = not marked
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    context
        .read<AdminBloc>()
        .add(const AdminEmployeeStatusLoadRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    context.read<AdminBloc>().add(const AdminEmployeeStatusLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Attendance Records'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            tooltip: 'Filter',
            onSelected: (val) => setState(() => _statusFilter = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('All Employees')),
              PopupMenuItem(value: 'present', child: Text('Present Today')),
              PopupMenuItem(value: 'pending', child: Text('Not Marked')),
            ],
          ),
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
            return const LoadingView(message: 'Loading records...');
          }

          if (state is AdminEmployeeStatusLoaded) {
            return RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: _refresh,
              child: _RecordsContent(
                state: state,
                searchQuery: _searchQuery,
                statusFilter: _statusFilter,
                searchController: _searchController,
                onSearchChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase().trim()),
              ),
            );
          }

          // Any other state — show reload button.
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_rounded,
                    size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                const Text(
                  'Could not load records.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Load Records'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Main content ─────────────────────────────────────────────────────────────

class _RecordsContent extends StatelessWidget {
  final AdminEmployeeStatusLoaded state;
  final String searchQuery;
  final String? statusFilter;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const _RecordsContent({
    required this.state,
    required this.searchQuery,
    required this.statusFilter,
    required this.searchController,
    required this.onSearchChanged,
  });

  List<EmployeeModel> get _filtered {
    var list = state.employees;

    // Apply status filter.
    if (statusFilter == 'present') {
      list = list
          .where((e) => state.todayAttendanceByEmployee[e.id] != null)
          .toList();
    } else if (statusFilter == 'pending') {
      list = list
          .where((e) => state.todayAttendanceByEmployee[e.id] == null)
          .toList();
    }

    // Apply search query.
    if (searchQuery.isNotEmpty) {
      list = list
          .where((e) =>
              e.name.toLowerCase().contains(searchQuery) ||
              e.id.toLowerCase().contains(searchQuery) ||
              e.email.toLowerCase().contains(searchQuery))
          .toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ─── Header subtitle ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.primaryBlue,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              'Manage and monitor employee attendance',
              style: TextStyle(
                  color: Colors.white.withAlpha(180), fontSize: 13),
            ),
          ),
        ),

        // ─── Summary cards ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Total\nEmployees',
                    value: state.totalEmployees.toString(),
                    icon: Icons.people_rounded,
                    iconColor: AppColors.primaryBlue,
                    iconBg: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Present\nToday',
                    value: state.presentToday.toString(),
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.success,
                    iconBg: AppColors.successLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Pending\nAttendance',
                    value: state.pendingToday.toString(),
                    icon: Icons.pending_rounded,
                    iconColor: AppColors.warning,
                    iconBg: AppColors.warningLight,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Search bar ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or ID...',
                hintStyle:
                    const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary, size: 20),
                filled: true,
                fillColor: AppColors.cardBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppColors.textTertiary, size: 18),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),

        // ─── Result count ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '${filtered.length} Employee${filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // ─── Empty state ──────────────────────────────────────────────
        if (filtered.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 64, color: AppColors.textTertiary),
                  SizedBox(height: 16),
                  Text(
                    'No employees match your search.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          // ─── Employee cards ───────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EmployeeAttendanceCard(
                    employee: filtered[i],
                    todayRecord:
                        state.todayAttendanceByEmployee[filtered[i].id],
                  ),
                ),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Employee attendance card ─────────────────────────────────────────────────

class _EmployeeAttendanceCard extends StatelessWidget {
  final EmployeeModel employee;
  final AttendanceModel? todayRecord;

  const _EmployeeAttendanceCard({
    required this.employee,
    required this.todayRecord,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecord = todayRecord != null;
    final isComplete = hasRecord && todayRecord!.hasCheckOut;

    final Color statusColor;
    final Color statusBg;
    final String statusLabel;

    if (!hasRecord) {
      statusColor = AppColors.textTertiary;
      statusBg = AppColors.surface;
      statusLabel = 'Not Marked';
    } else if (isComplete) {
      statusColor = AppColors.success;
      statusBg = AppColors.successLight;
      statusLabel = 'Present';
    } else {
      statusColor = AppColors.warning;
      statusBg = AppColors.warningLight;
      statusLabel = 'Checked In';
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmployeeDetailsScreen(employee: employee),
          ),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  employee.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${employee.id}  •  ${employee.email}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasRecord) ...[
                    const SizedBox(height: 4),
                    Text(
                      _attendanceSummary(todayRecord!),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),

            // Status badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                  bgColor: statusBg,
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _attendanceSummary(AttendanceModel r) {
    final inTime = r.checkInTime;
    final outTime = r.checkOutTime ?? '--:--';
    return 'In: $inTime  •  Out: $outTime';
  }
}
