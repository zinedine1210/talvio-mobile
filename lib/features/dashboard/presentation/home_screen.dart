import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/app_bar.dart';
import '../../../l10n/app_localizations.dart';
import 'dashboard_summary_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final me = ref.watch(currentEmployeeProvider);
    final isHr = me?['role'] == 'hr_admin';

    return Scaffold(
      appBar: TalvioAppBar(title: 'Talvio'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me?['name'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                t.homeGreeting(me!['name'].toString()),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          // HR is a management-only role here — an HR admin who also needs
          // to clock in/out gets a second, plain-employee account for that
          // (product decision), so this screen never mixes personal
          // attendance widgets into the HR view.
          if (isHr) const _HrMenuGrid() else ...[
            const TodayAttendanceCard(),
            const AnnouncementsPreviewCard(),
            const _EmployeeMenuGrid(),
          ],
        ],
      ),
    );
  }
}

class _MenuGridItem {
  const _MenuGridItem(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

class _EmployeeMenuGrid extends StatelessWidget {
  const _EmployeeMenuGrid();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _MenuGrid(items: [
      _MenuGridItem(Icons.fingerprint, t.attendanceMenu, '/attendance'),
      _MenuGridItem(Icons.event_available_outlined, t.leaveMenu, '/leave'),
      _MenuGridItem(Icons.schedule_outlined, t.overtimeMenu, '/overtime'),
      _MenuGridItem(Icons.edit_calendar_outlined, t.correctionMenu, '/corrections/new'),
      _MenuGridItem(Icons.receipt_outlined, t.myPayslipsTitle, '/payroll/my-slips'),
      _MenuGridItem(Icons.bar_chart_outlined, t.reportsMenu, '/reports'),
      _MenuGridItem(Icons.campaign_outlined, t.announcementsMenu, '/announcements'),
    ]);
  }
}

/// HR-only management menu — no personal attendance/leave/payslip items,
/// and no approval items either (leave/overtime/wfh/correction approvals
/// all moved behind the notification bell, same as the employee grid).
class _HrMenuGrid extends StatelessWidget {
  const _HrMenuGrid();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _MenuGrid(items: [
      _MenuGridItem(Icons.people_outline, t.manageEmployeesMenu, '/employees'),
      _MenuGridItem(Icons.apartment_outlined, t.manageDepartmentsMenu, '/departments'),
      _MenuGridItem(Icons.settings_outlined, t.companySettingsMenu, '/company/settings'),
      _MenuGridItem(Icons.rule_outlined, t.approvalConfigMenu, '/company/approval-configs'),
      _MenuGridItem(Icons.receipt_long_outlined, t.salaryComponentsTitle, '/payroll/salary-components'),
      _MenuGridItem(Icons.badge_outlined, t.employeeSalariesTitle, '/payroll/employees'),
      _MenuGridItem(Icons.payments_outlined, t.payrollRunsTitle, '/payroll/runs'),
      _MenuGridItem(Icons.bar_chart_outlined, t.reportsMenu, '/reports'),
      _MenuGridItem(Icons.campaign_outlined, t.announcementsMenu, '/announcements'),
    ]);
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items});
  final List<_MenuGridItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(item.route),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(item.icon, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
