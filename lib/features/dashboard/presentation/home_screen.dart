import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../attendance/attendance_status.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_summary_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentEmployeeProvider);
    final isHr = me?['role'] == 'hr_admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Talvio',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (isHr) const _HrHome() else const _EmployeeHome(),
        ],
      ),
    );
  }
}

class _EmployeeHome extends ConsumerWidget {
  const _EmployeeHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final me = ref.watch(currentEmployeeProvider);
    final name = me?['name']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.homeGreeting(name),
          style: const TextStyle(color: Color(0xFF134E4A), fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          t.homeSubtitleEmployee,
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
        const SizedBox(height: 20),
        const _AttendanceCta(),
        const SizedBox(height: 20),
        _MenuGrid(items: [
          _MenuTile(Icons.event_available_outlined, t.homeTileRequest, '/leave'),
          _MenuTile(Icons.receipt_outlined, t.homeTilePayslip, '/payroll/my-slips'),
          _MenuTile(Icons.campaign_outlined, t.announcementsMenu, '/announcements'),
          _MenuTile(Icons.bar_chart_outlined, t.homeTileAttendanceReport, '/attendance/report'),
        ]),
        const SizedBox(height: 20),
        const AnnouncementsPreviewCard(),
      ],
    );
  }
}

/// Teal gradient CTA card — 3 states depending on today's attendance record
/// (myAttendanceProvider): not yet clocked in, clocked in only (shows the
/// clock-in time + a clock-out CTA), or fully done (shows both times).
class _AttendanceCta extends ConsumerWidget {
  const _AttendanceCta();

  String _hhmm(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final recordsAsync = ref.watch(myAttendanceProvider);
    final today = recordsAsync.maybeWhen(
      data: (records) => findAttendanceForDate(records, todayDateString()),
      orElse: () => null,
    );
    final clockInAt = today?['clock_in_at']?.toString();
    final clockOutAt = today?['clock_out_at']?.toString();
    final hasClockedIn = clockInAt != null && clockInAt.isNotEmpty;
    final hasClockedOut = clockOutAt != null && clockOutAt.isNotEmpty;

    final pillLabel = hasClockedOut
        ? t.attendanceStatusDonePill
        : (hasClockedIn ? t.attendanceStatusInProgressPill : t.attendanceStatusNotStartedPill);
    final statusIcon = hasClockedOut
        ? Icons.check_circle_rounded
        : (hasClockedIn ? Icons.directions_walk_rounded : Icons.schedule_rounded);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.attendanceStatusCardTitle,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(pillLabel,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AttendanceTimeSlot(
                  label: t.clockInTimeLabel,
                  time: hasClockedIn ? _hhmm(clockInAt) : '--:--',
                  done: hasClockedIn,
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.25)),
              Expanded(
                child: _AttendanceTimeSlot(
                  label: t.clockOutTimeLabel,
                  time: hasClockedOut ? _hhmm(clockOutAt) : '--:--',
                  done: hasClockedOut,
                ),
              ),
            ],
          ),
          if (!hasClockedOut) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/attendance'),
                icon: const Icon(Icons.fingerprint, size: 18),
                label: Text(hasClockedIn ? t.homeClockOutCta : t.homeAttendanceCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceTimeSlot extends StatelessWidget {
  const _AttendanceTimeSlot({required this.label, required this.time, required this.done});
  final String label;
  final String time;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: Colors.white.withValues(alpha: done ? 1 : 0.6),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Text(time,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _HrHome extends ConsumerWidget {
  const _HrHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final me = ref.watch(currentEmployeeProvider);
    final name = me?['name']?.toString() ?? '';
    final statsAsync = ref.watch(hrDashboardStatsProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final pendingTotal = summaryAsync.maybeWhen(
      data: (s) =>
          ((s['pending_leave_approvals'] as num?)?.toInt() ?? 0) +
          ((s['pending_overtime_approvals'] as num?)?.toInt() ?? 0) +
          ((s['pending_wfh_reviews'] as num?)?.toInt() ?? 0) +
          ((s['pending_corrections'] as num?)?.toInt() ?? 0),
      orElse: () => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.homeGreeting(name),
          style: const TextStyle(color: Color(0xFF134E4A), fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(t.homeSubtitleHr, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
        const SizedBox(height: 20),
        statsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (stats) => _StatStrip(
            totalEmployees: stats.totalEmployees,
            pending: pendingTotal,
            presentToday: stats.presentToday,
          ),
        ),
        const SizedBox(height: 16),
        if (pendingTotal > 0) ...[
          _PendingBanner(count: pendingTotal),
          const SizedBox(height: 16),
        ],
        _MenuGrid(items: [
          _MenuTile(Icons.people_outline, t.hrTileEmployees, '/employees'),
          _MenuTile(Icons.apartment_outlined, t.hrTileMasterOrg, '/organization'),
          _MenuTile(Icons.payments_outlined, t.hrTilePayroll, '/payroll'),
          _MenuTile(Icons.bar_chart_outlined, t.reportsMenu, '/reports'),
          _MenuTile(Icons.settings_outlined, t.companySettingsTitle, '/company/settings'),
        ]),
        const SizedBox(height: 16),
        _AnnouncementRow(label: t.announcementsMenu),
      ],
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.totalEmployees, required this.pending, required this.presentToday});

  final int totalEmployees;
  final int pending;
  final int presentToday;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    Widget stat(String value, String label, Color valueColor) => Expanded(
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: valueColor)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            ],
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            stat('$totalEmployees', t.hrStatEmployeesLabel, const Color(0xFF0D9488)),
            stat('$pending', t.hrStatPendingLabel, const Color(0xFFEA580C)),
            stat('$presentToday', t.hrStatPresentLabel, const Color(0xFF134E4A)),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/notifications'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Color(0xFFFFEDD5), shape: BoxShape.circle),
                child: const Icon(Icons.fact_check_outlined, color: Color(0xFFEA580C), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.hrPendingBannerTitle(count),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(t.hrPendingBannerSubtitle,
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/announcements'),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.campaign_outlined, color: Color(0xFF0D9488)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile {
  const _MenuTile(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items});
  final List<_MenuTile> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        for (final item in items)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 24 * 2 - 12) / 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              // '/leave' dan '/attendance' itu bottom-nav tab (shell
              // branch) — harus go() buat pindah tab, bukan push() yang
              // numpuk shell baru di atas shell yang ada.
              onTap: () => const {'/leave', '/attendance'}.contains(item.route)
                  ? context.go(item.route)
                  : context.push(item.route),
              child: Container(
                height: 104,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: Color(0xFFCCFBF1), shape: BoxShape.circle),
                      child: Icon(item.icon, color: const Color(0xFF0D9488), size: 20),
                    ),
                    const Spacer(),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF134E4A),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
