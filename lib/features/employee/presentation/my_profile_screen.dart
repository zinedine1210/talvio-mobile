import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../leave/providers/leave_providers.dart';
import '../../report/providers/report_providers.dart';
import '../providers/employee_providers.dart';

/// This-month attendance stats for the profile stat strip — "Tidak hadir"
/// is approximated as missing-clockout + rejected days, since the backend
/// has no direct "absent" counter (see AttendanceSummaryRow).
final _myMonthStatsProvider =
    FutureProvider.autoDispose<({int present, int absent})>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month + 1, 0);
  String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final summary = await ref
      .watch(reportApiProvider)
      .getAttendanceSummary(dateFrom: fmt(from), dateTo: fmt(to));
  final rows = (summary['employees'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  if (rows.isEmpty) return (present: 0, absent: 0);
  final row = rows.first;
  final present = (row['days_present'] as num?)?.toInt() ?? 0;
  final absent = ((row['days_missing_clockout'] as num?)?.toInt() ?? 0) +
      ((row['days_rejected'] as num?)?.toInt() ?? 0);
  return (present: present, absent: absent);
});

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

  Future<void> _editProfile(BuildContext context, WidgetRef ref, Map<String, dynamic> me) async {
    final t = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: me['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: me['phone']?.toString() ?? '');
    final addressController = TextEditingController(text: me['address']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.editProfileLabel),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: t.nameLabel),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: t.phoneLabel),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: t.addressLabel),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: Text(t.cancelButton)),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              context.pop(true);
            },
            child: Text(t.submitButton),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await ref.read(employeeApiProvider).updateMe(
            name: nameController.text.trim(),
            phone: phoneController.text.trim(),
            address: addressController.text.trim(),
          );
      ref.invalidate(myProfileProvider);
    } on Object catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final meAsync = ref.watch(myProfileProvider);
    final statsAsync = ref.watch(_myMonthStatsProvider);
    final quotaAsync = ref.watch(myLeaveQuotaProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.myProfileMenu)),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (me) {
          final name = me['name']?.toString() ?? '-';
          final initials = name.trim().isEmpty
              ? '?'
              : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ProfileCard
              DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFFCCFBF1),
                        backgroundImage: (me['photo_url'] as String?)?.isNotEmpty == true
                            ? NetworkImage(me['photo_url'] as String)
                            : null,
                        child: (me['photo_url'] as String?)?.isNotEmpty != true
                            ? Text(initials,
                                style: const TextStyle(
                                    color: Color(0xFF0D9488), fontSize: 24, fontWeight: FontWeight.w700))
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
                      if (me['position'] != null) ...[
                        const SizedBox(height: 2),
                        Text(me['position'].toString(),
                            style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _editProfile(context, ref, me),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(t.editProfileLabel),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // DetailCard
              DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: t.emailLabel, value: me['email']?.toString()),
                      const Divider(height: 24),
                      _DetailRow(label: t.phoneLabel, value: me['phone']?.toString()),
                      const Divider(height: 24),
                      _DetailRow(label: t.nikLabel, value: me['nik']?.toString()),
                      const Divider(height: 24),
                      _DetailRow(label: t.addressLabel, value: me['address']?.toString()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // StatStrip
              DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: statsAsync.maybeWhen(data: (s) => '${s.present}', orElse: () => '-'),
                          label: t.statHadirLabel,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          value: statsAsync.maybeWhen(data: (s) => '${s.absent}', orElse: () => '-'),
                          label: t.statAbsentLabel,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          value: quotaAsync.maybeWhen(
                            data: (q) => '${(q['quota_days'] as num? ?? 0) - (q['used_days'] as num? ?? 0)}',
                            orElse: () => '-',
                          ),
                          label: t.statLeaveBalanceLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // MenuList
              DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.settings_outlined,
                      label: t.accountSettingsMenu,
                      onTap: () => context.push('/profile/settings'),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _MenuRow(
                      icon: Icons.language_outlined,
                      label: t.languageMenuTooltip,
                      onTap: () => context.push('/profile/language'),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _MenuRow(
                      icon: Icons.help_outline,
                      label: t.helpMenuLabel,
                      onTap: () => context.push('/profile/help'),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _MenuRow(
                      icon: Icons.logout,
                      label: t.logoutButton,
                      destructive: true,
                      onTap: () => _logout(context, ref),
                      showChevron: false,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value?.isNotEmpty == true ? value! : '-',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF134E4A), fontSize: 14)),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFDC2626) : const Color(0xFF134E4A);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
            if (showChevron) const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
