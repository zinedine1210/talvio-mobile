import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'api_client.dart';

/// Shell dengan bottom navigation 4 tab, beda per role sesuai figma:
/// employee = Beranda/Absensi/Permohonan/Profil, HR = Beranda/Karyawan/
/// Persetujuan/Profil. Router punya 6 branch tetap (indeks fixed); yang
/// berubah per role cuma 4 DESTINATION MANA yang ditampilkan + branch index
/// mana yang mereka tunjuk — branch yang tidak relevan untuk role itu
/// cuma tidak pernah muncul di nav, state-nya tetap hidup di IndexedStack.
/// Layar lain (izin, payroll, dst) tetap route biasa yang di-push di atas
/// shell ini.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _homeBranch = 0;
  static const _attendanceBranch = 1;
  static const _employeesBranch = 2;
  static const _leaveBranch = 3;
  static const _approvalsBranch = 4;
  static const _profileBranch = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final me = ref.watch(currentEmployeeProvider);
    final isHr = me?['role'] == 'hr_admin';

    final destinations = isHr
        ? const [
            (branch: _homeBranch, icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'homeMenu'),
            (branch: _employeesBranch, icon: Icons.people_outline, selectedIcon: Icons.people, label: 'manageEmployeesMenu'),
            (branch: _approvalsBranch, icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check, label: 'persetujuanTitle'),
            (branch: _profileBranch, icon: Icons.person_outline, selectedIcon: Icons.person, label: 'myProfileMenu'),
          ]
        : const [
            (branch: _homeBranch, icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'homeMenu'),
            (branch: _attendanceBranch, icon: Icons.fingerprint, selectedIcon: Icons.fingerprint, label: 'attendanceMenu'),
            (branch: _leaveBranch, icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check, label: 'leaveMenu'),
            (branch: _profileBranch, icon: Icons.person_outline, selectedIcon: Icons.person, label: 'myProfileMenu'),
          ];

    String labelFor(String key) => switch (key) {
          'homeMenu' => t.homeMenu,
          'manageEmployeesMenu' => t.manageEmployeesMenu,
          'persetujuanTitle' => t.persetujuanTitle,
          'myProfileMenu' => t.myProfileMenu,
          'attendanceMenu' => t.attendanceMenu,
          'leaveMenu' => t.leaveMenu,
          _ => key,
        };

    final selectedDisplayIndex = destinations.indexWhere((d) => d.branch == navigationShell.currentIndex);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedDisplayIndex < 0 ? 0 : selectedDisplayIndex,
        onDestinationSelected: (displayIndex) {
          final branch = destinations[displayIndex].branch;
          navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);
        },
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: labelFor(d.label),
            ),
        ],
      ),
    );
  }
}
