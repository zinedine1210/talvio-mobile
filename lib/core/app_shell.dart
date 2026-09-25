import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/providers/dashboard_providers.dart';
import '../l10n/app_localizations.dart';

/// Shell dengan bottom navigation untuk 3 tab utama (Home, Notifikasi,
/// Profil) — sama untuk role employee maupun HR, konten tiap tab yang
/// beda-beda per role (lihat HomeScreen). Layar lain (absensi, izin,
/// payroll, dst) tetap route biasa yang di-push di atas shell ini, jadi
/// bottom nav otomatis hilang saat masuk ke situ (pola standar mobile).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final pendingTotal = summaryAsync.maybeWhen(
      data: (s) =>
          ((s['pending_leave_approvals'] as num?)?.toInt() ?? 0) +
          ((s['pending_overtime_approvals'] as num?)?.toInt() ?? 0) +
          ((s['pending_wfh_reviews'] as num?)?.toInt() ?? 0) +
          ((s['pending_corrections'] as num?)?.toInt() ?? 0),
      orElse: () => 0,
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t.homeMenu,
          ),
          NavigationDestination(
            icon: pendingTotal > 0
                ? Badge(label: Text('$pendingTotal'), child: const Icon(Icons.notifications_outlined))
                : const Icon(Icons.notifications_outlined),
            selectedIcon: pendingTotal > 0
                ? Badge(label: Text('$pendingTotal'), child: const Icon(Icons.notifications))
                : const Icon(Icons.notifications),
            label: t.notificationsTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: t.myProfileMenu,
          ),
        ],
      ),
    );
  }
}
