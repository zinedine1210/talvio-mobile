import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/app_bar.dart';
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
      appBar: TalvioAppBar(title: t.myProfileMenu),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (me) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: (me['photo_url'] as String?)?.isNotEmpty == true
                          ? NetworkImage(me['photo_url'] as String)
                          : null,
                      child: (me['photo_url'] as String?)?.isNotEmpty != true
                          ? Icon(Icons.person,
                              size: 44, color: Theme.of(context).colorScheme.onPrimaryContainer)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      me['name']?.toString() ?? '-',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (me['position'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        me['position'].toString(),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _SectionHeader(t.profileSectionTitle),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _ProfileRow(label: t.nameLabel, value: me['name']?.toString()),
                    _ProfileRow(label: t.emailLabel, value: me['email']?.toString()),
                    _ProfileRow(label: t.phoneLabel, value: me['phone']?.toString()),
                    _ProfileRow(label: t.positionLabel, value: me['position']?.toString()),
                    _ProfileRow(label: t.roleLabel, value: me['role']?.toString()),
                    _ProfileRow(
                        label: t.statusLabel, value: me['status']?.toString(), isLast: true),
                  ],
                ),
              ),
            ),
            _SectionHeader(t.appSectionTitle),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(t.languageMenuTooltip),
                trailing: DropdownButton<Locale>(
                  value: locale,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: Locale('id'), child: Text('Bahasa Indonesia')),
                    DropdownMenuItem(value: Locale('en'), child: Text('English')),
                  ],
                  onChanged: (l) {
                    if (l != null) ref.read(localeProvider.notifier).setLocale(l);
                  },
                ),
              ),
            ),
            _SectionHeader(t.accountSectionTitle),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: Text(t.logoutButton,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => _logout(context, ref),
              ),
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
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value, this.isLast = false});
  final String label;
  final String? value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: Text(value ?? '-', textAlign: TextAlign.right)),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}
