import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/employee_providers.dart';

class DepartmentListScreen extends ConsumerWidget {
  const DepartmentListScreen({super.key});

  Future<void> _addDepartment(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.addDepartmentTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: t.departmentNameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t.saveButton),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(employeeApiProvider).createDepartment(name);
      ref.invalidate(departmentListProvider);
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(translateError(context, e))));
      }
    }
  }

  Future<void> _editDepartment(
      BuildContext context, WidgetRef ref, Map<String, dynamic> department) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: department['name']?.toString() ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.editDepartmentTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: t.departmentNameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t.saveButton),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(employeeApiProvider).updateDepartment(department['id'] as int, name);
      ref.invalidate(departmentListProvider);
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(translateError(context, e))));
      }
    }
  }

  Future<void> _deactivateDepartment(
      BuildContext context, WidgetRef ref, Map<String, dynamic> department) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deactivateDepartmentTitle),
        content: Text(t.confirmDeactivateDepartment(department['name']?.toString() ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.deactivateButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(employeeApiProvider).deactivateDepartment(department['id'] as int);
      ref.invalidate(departmentListProvider);
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(translateError(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final departmentsAsync = ref.watch(departmentListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.departmentsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addDepartment(context, ref),
        child: const Icon(Icons.add),
      ),
      body: departmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (departments) {
          if (departments.isEmpty) {
            return Center(child: Text(t.noDepartmentsYet));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: departments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final department = departments[i];
              final isActive = department['status'] == 'active';
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.apartment_outlined, color: colorScheme.onPrimaryContainer),
                  ),
                  title: Text(department['name']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text(isActive ? t.activeStatus : t.inactiveStatus),
                        backgroundColor: isActive
                            ? colorScheme.tertiaryContainer
                            : colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(
                          color:
                              isActive ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isActive)
                        IconButton(
                          icon: const Icon(Icons.person_off_outlined),
                          onPressed: () => _deactivateDepartment(context, ref, department),
                        ),
                    ],
                  ),
                  onTap: () => _editDepartment(context, ref, department),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
