import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../attendance/attendance_status.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../providers/dashboard_providers.dart';

/// Today's clock-in/out state, front and center on the employee home
/// screen — the thing people open the app to check first. Renders nothing
/// while loading/on error so a slow fetch never blocks the rest of the
/// home screen.
class TodayAttendanceCard extends ConsumerWidget {
  const TodayAttendanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final recordsAsync = ref.watch(myAttendanceProvider);

    return recordsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (records) {
        final today = findAttendanceForDate(records, todayDateString());
        final clockInAt = today?['clock_in_at']?.toString();
        final clockOutAt = (today?['clock_out_at']?.toString().isNotEmpty ?? false)
            ? today!['clock_out_at'].toString()
            : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.todayAttendanceTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (clockInAt == null)
                    Text(t.errorNoOpenClockin)
                  else
                    Row(
                      children: [
                        Expanded(child: _timeColumn(context, t.clockInTimeLabel, clockInAt)),
                        if (clockOutAt != null)
                          Expanded(child: _timeColumn(context, t.clockOutTimeLabel, clockOutAt)),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (clockOutAt == null)
                    FilledButton(
                      // '/attendance' jadi bottom-nav tab sekarang — pakai
                      // go() buat pindah tab, bukan push() yang numpuk shell
                      // baru di atas shell yang ada.
                      onPressed: () => context.go('/attendance'),
                      child: Text(clockInAt == null ? t.clockInButton : t.clockOutButton),
                    )
                  else
                    Text(t.alreadyClockedTodayMessage,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _timeColumn(BuildContext context, String label, String iso) {
    final local = DateTime.parse(iso).toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('$hh:$mm', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ],
    );
  }
}

/// Recent announcements preview. Pending-approval counts used to live here
/// too, but those moved to the notification bell in the app bar so this
/// card only ever shows informational content.
class AnnouncementsPreviewCard extends ConsumerWidget {
  const AnnouncementsPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        final announcements =
            (summary['recent_announcements'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        if (announcements.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              ),
            ),
          ),
        );
      },
    );
  }
}
