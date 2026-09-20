import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/employee_providers.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat profil: $e')),
        data: (me) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileRow(label: 'Nama', value: me['name']?.toString()),
            _ProfileRow(label: 'Email', value: me['email']?.toString()),
            _ProfileRow(label: 'Telepon', value: me['phone']?.toString()),
            _ProfileRow(label: 'Jabatan', value: me['position']?.toString()),
            _ProfileRow(label: 'Role', value: me['role']?.toString()),
            _ProfileRow(label: 'Status', value: me['status']?.toString()),
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
