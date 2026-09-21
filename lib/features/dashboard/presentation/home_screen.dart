import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../l10n/app_localizations.dart';

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
