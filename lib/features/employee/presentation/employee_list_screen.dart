import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/employee_providers.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karyawan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.apartment),
            tooltip: 'Kelola Departemen',
            onPressed: () => context.push('/departments'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/employees/new');
          ref.invalidate(employeeListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
        data: (employees) {
          if (employees.isEmpty) {
            return const Center(child: Text('Belum ada karyawan'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(employeeListProvider),
            child: ListView.separated(
              itemCount: employees.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = employees[i];
                final isActive = e['status'] == 'active';
                return ListTile(
                  title: Text(e['name']?.toString() ?? '-'),
                  subtitle: Text('${e['email'] ?? '-'} · ${e['position'] ?? '-'}'),
                  trailing: Chip(
                    label: Text(isActive ? 'Aktif' : 'Nonaktif'),
                    backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade300,
                  ),
                  onTap: () async {
                    await context.push('/employees/edit', extra: e);
                    ref.invalidate(employeeListProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
