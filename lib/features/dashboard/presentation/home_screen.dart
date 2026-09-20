import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentEmployeeProvider);
    final isHr = me?['role'] == 'hr_admin';

    return Scaffold(
      appBar: AppBar(title: Text('Talvio${me?['name'] != null ? ' — ${me!['name']}' : ''}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isHr) ...[
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Kelola Karyawan'),
              onTap: () => context.push('/employees'),
            ),
            ListTile(
              leading: const Icon(Icons.apartment),
              title: const Text('Kelola Departemen'),
              onTap: () => context.push('/departments'),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil Saya'),
              onTap: () => context.push('/profile'),
            ),
        ],
      ),
    );
  }
}
