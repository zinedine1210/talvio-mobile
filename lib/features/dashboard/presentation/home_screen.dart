import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final me = ref.watch(currentEmployeeProvider);
    final isHr = me?['role'] == 'hr_admin';
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Talvio${me?['name'] != null ? ' — ${me!['name']}' : ''}'),
        actions: [
          PopupMenuButton<Locale>(
            tooltip: t.languageMenuTooltip,
            icon: const Icon(Icons.language),
            initialValue: locale,
            onSelected: (l) => ref.read(localeProvider.notifier).setLocale(l),
            itemBuilder: (context) => const [
              PopupMenuItem(value: Locale('id'), child: Text('Bahasa Indonesia')),
              PopupMenuItem(value: Locale('en'), child: Text('English')),
            ],
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
          ] else
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(t.myProfileMenu),
              onTap: () => context.push('/profile'),
            ),
        ],
      ),
    );
  }
}
