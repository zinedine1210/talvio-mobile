import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/employee_providers.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.employeesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.apartment),
            tooltip: t.manageDepartmentsMenu,
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
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (employees) {
          if (employees.isEmpty) {
            return Center(child: Text(t.noEmployeesYet));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(employeeListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: employees.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = employees[i];
                final isActive = e['status'] == 'active';
                final name = e['name']?.toString() ?? '-';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                final colorScheme = Theme.of(context).colorScheme;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(initial, style: TextStyle(color: colorScheme.onPrimaryContainer)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${e['email'] ?? '-'} · ${e['position'] ?? '-'}'),
                    trailing: Chip(
                      label: Text(isActive ? t.activeStatus : t.inactiveStatus),
                      backgroundColor: isActive
                          ? colorScheme.tertiaryContainer
                          : colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: isActive ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () async {
                      await context.push('/employees/edit', extra: e);
                      ref.invalidate(employeeListProvider);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
