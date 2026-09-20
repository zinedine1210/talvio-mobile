import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/employee_providers.dart';

class DepartmentListScreen extends ConsumerWidget {
  const DepartmentListScreen({super.key});

  Future<void> _addDepartment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Departemen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nama Departemen'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(employeeApiProvider).createDepartment(name);
      ref.invalidate(departmentListProvider);
    } on DioException {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal menambah departemen')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Departemen')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addDepartment(context, ref),
        child: const Icon(Icons.add),
      ),
      body: departmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
        data: (departments) {
          if (departments.isEmpty) {
            return const Center(child: Text('Belum ada departemen'));
          }
          return ListView.separated(
            itemCount: departments.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => ListTile(
              title: Text(departments[i]['name']?.toString() ?? '-'),
            ),
          );
        },
      ),
    );
  }
}
