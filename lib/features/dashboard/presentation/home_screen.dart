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
    final me = ref.watch(currentEmployeeProvider);
    final isHr = me?['role'] == 'hr_admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('Talvio${me?['name'] != null ? ' — ${me!['name']}' : ''}'),
        actions: [
          IconButton(
            tooltip: t.myProfileMenu,
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(t.attendanceMenu),
            onTap: () => context.push('/attendance'),
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: Text(t.leaveMenu),
            onTap: () => context.push('/leave'),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in),
            title: Text(t.leaveApprovalsMenu),
            onTap: () => context.push('/leave/approvals'),
          ),
          if (isHr) ...[
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(t.manageEmployeesMenu),
              onTap: () => context.push('/employees'),
            ),
            ListTile(
              leading: const Icon(Icons.apartment),
              title: Text(t.manageDepartmentsMenu),
              onTap: () => context.push('/departments'),
            ),
            ListTile(
              leading: const Icon(Icons.rate_review),
              title: Text(t.pendingReviewMenu),
              onTap: () => context.push('/attendance/pending-review'),
            ),
            ListTile(
              leading: const Icon(Icons.rule),
              title: Text(t.approvalConfigMenu),
              onTap: () => context.push('/company/approval-configs'),
            ),
          ],
        ],
      ),
    );
  }
}
