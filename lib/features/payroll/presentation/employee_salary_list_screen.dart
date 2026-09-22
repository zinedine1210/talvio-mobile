import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';

/// HR-only: pick an employee to edit their base salary and manage their
/// assigned salary components — reuses the existing employee list (not the
/// employee module's own screen, this is a payroll-scoped picker).
class EmployeeSalaryListScreen extends ConsumerWidget {
  const EmployeeSalaryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final employeesAsync = ref.watch(employeeListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.employeeSalariesTitle)),
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
              padding: const EdgeInsets.all(16),
              itemCount: employees.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final emp = employees[i];
                final name = emp['name']?.toString() ?? '-';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                final baseSalary = (emp['base_salary'] as num?)?.toInt() ?? 0;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(initial, style: TextStyle(color: colorScheme.onPrimaryContainer)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(formatRupiah(baseSalary)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.push('/payroll/employees/salary', extra: emp);
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
