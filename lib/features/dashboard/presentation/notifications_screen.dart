import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_bar.dart';
import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/dashboard_providers.dart';

class _PendingGroup {
  const _PendingGroup(this.label, this.count, this.icon, this.route);
  final String label;
  final int count;
  final IconData icon;
  final String route;
}

/// Pending approvals across every request type, grouped by type rather
/// than one row per request — tapping a group opens the existing
/// type-specific approval screen, which already lists each item with
/// inline approve/reject. Keeps this screen a thin router instead of
/// duplicating that (already-tested) UI.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: TalvioAppBar(title: t.notificationsTitle),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (summary) {
          int count(String key) => (summary[key] as num?)?.toInt() ?? 0;
          final groups = [
            _PendingGroup(t.dashboardPendingLeaveLabel, count('pending_leave_approvals'),
                Icons.event_available_outlined, '/leave/approvals'),
            _PendingGroup(t.dashboardPendingOvertimeLabel, count('pending_overtime_approvals'),
                Icons.schedule_outlined, '/overtime/approvals'),
            _PendingGroup(t.dashboardPendingWfhLabel, count('pending_wfh_reviews'),
                Icons.rate_review_outlined, '/attendance/pending-review'),
            _PendingGroup(t.dashboardPendingCorrectionLabel, count('pending_corrections'),
                Icons.fact_check_outlined, '/corrections/approvals'),
          ].where((g) => g.count > 0).toList();

          if (groups.isEmpty) {
            return Center(child: Text(t.notificationsEmptyMessage));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final g = groups[i];
                final colorScheme = Theme.of(context).colorScheme;
                return Card(
                  child: ListTile(
                    onTap: () => context.push(g.route),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(g.icon, color: colorScheme.onPrimaryContainer),
                    ),
                    title: Text(g.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: CircleAvatar(
                      radius: 12,
                      backgroundColor: colorScheme.error,
                      child: Text('${g.count}',
                          style: TextStyle(fontSize: 12, color: colorScheme.onError)),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
