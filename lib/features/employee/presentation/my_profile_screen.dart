import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/employee_providers.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final meAsync = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.myProfileMenu)),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (me) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileRow(label: t.nameLabel, value: me['name']?.toString()),
            _ProfileRow(label: t.emailLabel, value: me['email']?.toString()),
            _ProfileRow(label: t.phoneLabel, value: me['phone']?.toString()),
            _ProfileRow(label: t.positionLabel, value: me['position']?.toString()),
            _ProfileRow(label: t.roleLabel, value: me['role']?.toString()),
            _ProfileRow(label: t.statusLabel, value: me['status']?.toString()),
          ],
        ),
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
