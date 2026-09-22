import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/dashboard_providers.dart';

/// Sits at the top of HomeScreen's ListView, above the menu cards. Renders
/// nothing (SizedBox.shrink) while loading or on error — a failed summary
/// fetch shouldn't block the rest of the home screen from being usable.
class DashboardSummaryCard extends ConsumerWidget {
  const DashboardSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        final chips = <Widget?>[
          _pendingChip(context, t.dashboardPendingLeaveLabel, summary['pending_leave_approvals'],
              () => context.push('/leave/approvals')),
          _pendingChip(context, t.dashboardPendingOvertimeLabel, summary['pending_overtime_approvals'],
              () => context.push('/overtime/approvals')),
          _pendingChip(context, t.dashboardPendingWfhLabel, summary['pending_wfh_reviews'],
              () => context.push('/attendance/pending-review')),
          _pendingChip(context, t.dashboardPendingCorrectionLabel, summary['pending_corrections'],
              () => context.push('/corrections/approvals')),
        ].whereType<Widget>().toList();

        final announcements =
            (summary['recent_announcements'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        if (chips.isEmpty && announcements.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chips.isNotEmpty)
                    Wrap(spacing: 8, runSpacing: 8, children: chips),
                  if (announcements.isNotEmpty) ...[
                    if (chips.isNotEmpty) const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t.dashboardAnnouncementsHeading,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        TextButton(
                          onPressed: () => context.push('/announcements'),
                          child: Text(t.dashboardSeeAllButton),
                        ),
                      ],
                    ),
                    for (final a in announcements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(a['title']?.toString() ?? '-',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _pendingChip(BuildContext context, String label, Object? countValue, VoidCallback onTap) {
    final count = (countValue as num?)?.toInt() ?? 0;
    if (count <= 0) return null;
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text('$label ($count)'),
      backgroundColor: colorScheme.secondaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
      onPressed: onTap,
    );
  }
}
