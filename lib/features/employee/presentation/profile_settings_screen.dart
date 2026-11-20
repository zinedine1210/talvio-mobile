import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/employee_providers.dart';

/// "10b Pengaturan Akun" — notification toggles persisted via
/// PATCH /employees/me/notifications (real storage, but no push/email
/// sender exists yet to honor it — see models.Employee.NotifyPush doc
/// comment on the backend). "Ubah kata sandi" lives here too now that
/// PATCH /employees/me/password exists.
class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  Future<void> _togglePush(WidgetRef ref, BuildContext context, Map<String, dynamic> me, bool value) async {
    try {
      await ref.read(employeeApiProvider).updateNotificationPrefs(
            notifyPush: value,
            notifyEmail: me['notify_email'] == true,
          );
      ref.invalidate(myProfileProvider);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  Future<void> _toggleEmail(WidgetRef ref, BuildContext context, Map<String, dynamic> me, bool value) async {
    try {
      await ref.read(employeeApiProvider).updateNotificationPrefs(
            notifyPush: me['notify_push'] != false,
            notifyEmail: value,
          );
      ref.invalidate(myProfileProvider);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final meAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.accountSettingsMenu)),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (me) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Keamanan',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: Color(0xFF134E4A)),
                title: Text(t.changePasswordLabel),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                onTap: () => context.push('/profile/change-password'),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t.notificationsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    value: me['notify_push'] != false,
                    onChanged: (v) => _togglePush(ref, context, me, v),
                    title: Text(t.pushNotificationLabel),
                    activeTrackColor: const Color(0xFF0D9488),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: me['notify_email'] == true,
                    onChanged: (v) => _toggleEmail(ref, context, me, v),
                    title: Text(t.emailNotificationLabel),
                    activeTrackColor: const Color(0xFF0D9488),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
