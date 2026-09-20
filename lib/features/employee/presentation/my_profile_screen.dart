import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/error_translator.dart';
import '../../../core/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/employee_providers.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.logoutConfirmTitle),
        content: Text(t.logoutConfirmMessage),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: Text(t.cancelButton)),
          FilledButton(onPressed: () => context.pop(true), child: Text(t.logoutButton)),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(authTokenProvider.notifier).set(null);
    ref.read(currentEmployeeProvider.notifier).set(null);
    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final meAsync = ref.watch(myProfileProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.myProfileMenu)),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (me) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundImage: (me['photo_url'] as String?)?.isNotEmpty == true
                    ? NetworkImage(me['photo_url'] as String)
                    : null,
                child: (me['photo_url'] as String?)?.isNotEmpty != true
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _SectionHeader(t.profileSectionTitle),
            _ProfileRow(label: t.nameLabel, value: me['name']?.toString()),
            _ProfileRow(label: t.emailLabel, value: me['email']?.toString()),
            _ProfileRow(label: t.phoneLabel, value: me['phone']?.toString()),
            _ProfileRow(label: t.positionLabel, value: me['position']?.toString()),
            _ProfileRow(label: t.roleLabel, value: me['role']?.toString()),
            _ProfileRow(label: t.statusLabel, value: me['status']?.toString()),
            _SectionHeader(t.appSectionTitle),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language),
              title: Text(t.languageMenuTooltip),
              trailing: DropdownButton<Locale>(
                value: locale,
                items: const [
                  DropdownMenuItem(value: Locale('id'), child: Text('Bahasa Indonesia')),
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                ],
                onChanged: (l) {
                  if (l != null) ref.read(localeProvider.notifier).setLocale(l);
                },
              ),
            ),
            _SectionHeader(t.accountSectionTitle),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: Text(t.logoutButton),
              onTap: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value ?? '-')),
        ],
      ),
    );
  }
}
