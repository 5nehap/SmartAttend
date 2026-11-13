import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/employee_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/dashboard_widgets.dart';
import '../../../shared/widgets/loading_view.dart';
import '../bloc/admin_bloc.dart';
import 'employee_details_screen.dart';

class EmployeeRecordsScreen extends StatefulWidget {
  const EmployeeRecordsScreen({super.key});

  @override
  State<EmployeeRecordsScreen> createState() => _EmployeeRecordsScreenState();
}

class _EmployeeRecordsScreenState extends State<EmployeeRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<AdminBloc>().add(const AdminAttendanceLoadRequested());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<AdminBloc>().add(const AdminAttendanceLoadRequested());
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All Records'),
            Tab(text: 'Employees'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllRecordsTab(),
          _EmployeesTab(),
        ],
      ),
    );
  }
}

class _AllRecordsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const LoadingView(message: 'Loading records...');
        }
        if (state is AdminAttendanceLoaded) {
          final records = state.records;
          if (records.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded,
                      size: 64, color: AppColors.textTertiary),
                  SizedBox(height: 16),
                  Text('No attendance records found.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _AdminRecordCard(record: records[i]),
          );
        }
        // For other states (DashboardLoaded, etc.), re-trigger load.
        return Center(
          child: ElevatedButton.icon(
            onPressed: () => context
                .read<AdminBloc>()
                .add(const AdminAttendanceLoadRequested()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Load Records'),
          ),
        );
      },
    );
  }
}

class _EmployeesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const LoadingView(message: 'Loading employees...');
        }
        if (state is AdminEmployeesLoaded) {
          final employees = state.employees;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _EmployeeTile(employee: employees[i]),
          );
        }
        return Center(
          child: ElevatedButton.icon(
            onPressed: () => context
                .read<AdminBloc>()
                .add(const AdminEmployeesLoadRequested()),
            icon: const Icon(Icons.people_rounded),
            label: const Text('Load Employees'),
          ),
        );
      },
    );
  }
}

class _AdminRecordCard extends StatelessWidget {
  final AttendanceModel record;

  const _AdminRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final isComplete = record.hasCheckOut;
    final statusColor =
        isComplete ? AppColors.success : AppColors.warning;
    final statusBg =
        isComplete ? AppColors.successLight : AppColors.warningLight;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                record.employeeName[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 18,
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
                  '${record.date}  •  In: ${record.checkInTime}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (record.checkOutTime != null)
                  Text(
                    'Out: ${record.checkOutTime}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
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
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final EmployeeModel employee;

  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    final isAdmin = employee.role == 'admin';
    return GestureDetector(
      onTap: isAdmin
          ? null
          : () {
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    isAdmin ? AppColors.primaryLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  employee.name[0].toUpperCase(),
                  style: TextStyle(
                    color:
                        isAdmin ? AppColors.primaryBlue : AppColors.success,
                    fontSize: 18,
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
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: employee.role.toUpperCase(),
              color: isAdmin ? AppColors.primaryBlue : AppColors.success,
              bgColor:
                  isAdmin ? AppColors.primaryLight : AppColors.successLight,
            ),
            if (!isAdmin) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
