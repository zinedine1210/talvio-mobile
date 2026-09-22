import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/payroll_providers.dart';

/// HR-only: edit one employee's base_salary and manage which salary
/// components are assigned to them. `employee` comes from the router's
/// `extra` (see employee_salary_list_screen.dart).
class EmployeeSalaryDetailScreen extends ConsumerStatefulWidget {
  const EmployeeSalaryDetailScreen({super.key, required this.employee});

  final Map<String, dynamic> employee;

  @override
  ConsumerState<EmployeeSalaryDetailScreen> createState() => _EmployeeSalaryDetailScreenState();
}

class _EmployeeSalaryDetailScreenState extends ConsumerState<EmployeeSalaryDetailScreen> {
  late final TextEditingController _salaryController;
  bool _isSaving = false;

  int get _employeeId => widget.employee['id'] as int;

  @override
  void initState() {
    super.initState();
    final baseSalary = (widget.employee['base_salary'] as num?)?.toInt() ?? 0;
    _salaryController = TextEditingController(
      text: baseSalary == 0 ? '' : baseSalary.toString(),
    );
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveSalary() async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await ref.read(payrollApiProvider).updateEmployeeSalary(
            _employeeId,
            parseRupiahInput(_salaryController.text),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.salaryUpdatedMessage)));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _assignComponent(List<Map<String, dynamic>> allComponents,
      List<Map<String, dynamic>> assigned) async {
    final t = AppLocalizations.of(context)!;
    final assignedComponentIds = assigned.map((a) => a['salary_component_id']).toSet();
    final available = allComponents.where((c) => !assignedComponentIds.contains(c['id'])).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.noMoreSalaryComponentsToAssign)));
      return;
    }
    var selected = available.first['id'] as int;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(t.assignSalaryComponentTitle),
          content: DropdownButtonFormField<int>(
            initialValue: selected,
            items: available
                .map((c) => DropdownMenuItem(
                      value: c['id'] as int,
                      child: Text(c['name']?.toString() ?? '-'),
                    ))
                .toList(),
            onChanged: (v) => setDialogState(() => selected = v ?? selected),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.cancelButton)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true), child: Text(t.saveButton)),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(payrollApiProvider).assignSalaryComponent(_employeeId, selected);
      ref.invalidate(employeeSalaryComponentsProvider(_employeeId));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  Future<void> _removeComponent(int assignmentId) async {
    try {
      await ref.read(payrollApiProvider).removeEmployeeSalaryComponent(_employeeId, assignmentId);
      ref.invalidate(employeeSalaryComponentsProvider(_employeeId));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final name = widget.employee['name']?.toString() ?? '-';
    final componentsAsync = ref.watch(salaryComponentsProvider);
    final assignedAsync = ref.watch(employeeSalaryComponentsProvider(_employeeId));

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.baseSalaryLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RupiahInputFormatter()],
                    decoration: const InputDecoration(prefixText: 'Rp '),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveSalary,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.saveButton),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.salaryComponentsTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              componentsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (components) => assignedAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (assigned) => IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _assignComponent(components, assigned),
                  ),
                ),
              ),
            ],
          ),
          assignedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(translateError(context, e)),
            data: (assigned) {
              if (assigned.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(t.noSalaryComponentsAssigned),
                );
              }
              final components = componentsAsync.value ?? const [];
              return Column(
                children: assigned.map((a) {
                  final matches = components.where((c) => c['id'] == a['salary_component_id']);
                  final comp = matches.isNotEmpty ? matches.first : null;
                  return Card(
                    child: ListTile(
                      title: Text(comp?['name']?.toString() ?? '-'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeComponent(a['id'] as int),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
