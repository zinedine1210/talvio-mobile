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
          ],
        ],
      ),
    );
  }
}
