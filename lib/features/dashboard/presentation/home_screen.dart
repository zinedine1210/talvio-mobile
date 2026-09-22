import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
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
      appBar: AppBar(
        title: const Text('Talvio'),
        actions: [
          IconButton(
            tooltip: t.myProfileMenu,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
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
          const DashboardSummaryCard(),
          _MenuCard(
            icon: Icons.fingerprint,
            label: t.attendanceMenu,
            onTap: () => context.push('/attendance'),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.event_available_outlined,
            label: t.leaveMenu,
            onTap: () => context.push('/leave'),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.assignment_turned_in_outlined,
            label: t.leaveApprovalsMenu,
            onTap: () => context.push('/leave/approvals'),
          ),
          const SizedBox(height: 12),
          // Not HR-gated: wfh_review can route to a plain supervisor via
          // approval_configs (see approval.Resolve on the backend), same as
          // leave approvals above — the server enforces who's actually
          // allowed to act on each item, this menu is just navigation.
          _MenuCard(
            icon: Icons.rate_review_outlined,
            label: t.pendingReviewMenu,
            onTap: () => context.push('/attendance/pending-review'),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.edit_calendar_outlined,
            label: t.correctionMenu,
            onTap: () => context.push('/corrections/new'),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.schedule_outlined,
            label: t.overtimeMenu,
            onTap: () => context.push('/overtime'),
          ),
          const SizedBox(height: 12),
          // Not HR-gated, same reasoning as leave/wfh_review approvals —
          // overtime routes through the same resolver.
          _MenuCard(
            icon: Icons.assignment_turned_in_outlined,
            label: t.overtimeApprovalsMenu,
            onTap: () => context.push('/overtime/approvals'),
          ),
          const SizedBox(height: 12),
          // Not HR-gated: the screen hides the employee-filter dropdown for
          // non-HR users and shows only their own data instead (same pattern
          // as pendingReviewMenu above).
          _MenuCard(
            icon: Icons.bar_chart_outlined,
            label: t.reportsMenu,
            onTap: () => context.push('/reports'),
          ),
          const SizedBox(height: 12),
          // Not HR-gated: visibility is filtered server-side per employee
          // (all-targeted + their own department's announcements).
          _MenuCard(
            icon: Icons.campaign_outlined,
            label: t.announcementsMenu,
            onTap: () => context.push('/announcements'),
          ),
          const SizedBox(height: 12),
          // Not HR-gated: every employee (including HR) wants their own
          // payslips, unlike the HR-only payroll management items below.
          _MenuCard(
            icon: Icons.receipt_outlined,
            label: t.myPayslipsTitle,
            onTap: () => context.push('/payroll/my-slips'),
          ),
          if (isHr) ...[
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.people_outline,
              label: t.manageEmployeesMenu,
              onTap: () => context.push('/employees'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.apartment_outlined,
              label: t.manageDepartmentsMenu,
              onTap: () => context.push('/departments'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.rule_outlined,
              label: t.approvalConfigMenu,
              onTap: () => context.push('/company/approval-configs'),
            ),
            const SizedBox(height: 12),
            // HR-only for real, unlike the menu items above — attendance
            // corrections are hardcoded to HR, never routed through the
            // approval resolver (SPEC.md).
            _MenuCard(
              icon: Icons.fact_check_outlined,
              label: t.correctionApprovalsMenu,
              onTap: () => context.push('/corrections/approvals'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.receipt_long_outlined,
              label: t.salaryComponentsTitle,
              onTap: () => context.push('/payroll/salary-components'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.badge_outlined,
              label: t.employeeSalariesTitle,
              onTap: () => context.push('/payroll/employees'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.payments_outlined,
              label: t.payrollRunsTitle,
              onTap: () => context.push('/payroll/runs'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(icon, color: colorScheme.onPrimaryContainer),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
