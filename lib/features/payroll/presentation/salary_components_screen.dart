import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/payroll_providers.dart';

/// HR-only: manage the company's reusable allowance/deduction definitions
/// (salary_components). Assigning one to a specific employee happens on
/// employee_salary_detail_screen.dart, not here.
class SalaryComponentsScreen extends ConsumerWidget {
  const SalaryComponentsScreen({super.key});

  Future<void> _addComponent(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    var type = 'allowance';
    var amountType = 'fixed';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(t.addSalaryComponentTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: t.salaryComponentNameLabel),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: t.salaryComponentTypeLabel),
                  items: [
                    DropdownMenuItem(value: 'allowance', child: Text(t.salaryComponentAllowance)),
                    DropdownMenuItem(value: 'deduction', child: Text(t.salaryComponentDeduction)),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'allowance'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: amountType,
                  decoration: InputDecoration(labelText: t.amountTypeLabel),
                  items: [
                    DropdownMenuItem(value: 'fixed', child: Text(t.amountTypeFixed)),
                    DropdownMenuItem(value: 'percentage', child: Text(t.amountTypePercentage)),
                  ],
                  onChanged: (v) => setDialogState(() => amountType = v ?? 'fixed'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: amountType == 'fixed' ? [RupiahInputFormatter()] : null,
                  decoration: InputDecoration(
                    labelText: amountType == 'fixed' ? t.amountRupiahLabel : t.amountPercentLabel,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.cancelButton)),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.saveButton),
            ),
          ],
        ),
      ),
    );
    if (result != true || nameController.text.trim().isEmpty) return;
    final amount = amountType == 'fixed'
        ? parseRupiahInput(amountController.text)
        : int.tryParse(amountController.text) ?? 0;
    try {
      await ref.read(payrollApiProvider).createSalaryComponent(
            name: nameController.text.trim(),
            type: type,
            amountType: amountType,
            amount: amount,
          );
      ref.invalidate(salaryComponentsProvider);
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
    final componentsAsync = ref.watch(salaryComponentsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.salaryComponentsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addComponent(context, ref),
        child: const Icon(Icons.add),
      ),
      body: componentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (components) {
          if (components.isEmpty) {
            return Center(child: Text(t.noSalaryComponentsYet));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(salaryComponentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: components.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final comp = components[i];
                final isAllowance = comp['type'] == 'allowance';
                final isPercentage = comp['amount_type'] == 'percentage';
                final amount = (comp['amount'] as num?)?.toInt() ?? 0;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor:
                          isAllowance ? colorScheme.tertiaryContainer : colorScheme.errorContainer,
                      child: Icon(
                        isAllowance ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: isAllowance
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onErrorContainer,
                      ),
                    ),
                    title: Text(comp['name']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(isAllowance ? t.salaryComponentAllowance : t.salaryComponentDeduction),
                    trailing: Text(
                      isPercentage ? '$amount%' : formatRupiah(amount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
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
