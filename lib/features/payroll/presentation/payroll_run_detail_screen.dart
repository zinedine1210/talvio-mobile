import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/payroll_providers.dart';

/// HR-only: per-employee payslip breakdown for one payroll run.
class PayrollRunDetailScreen extends ConsumerWidget {
  const PayrollRunDetailScreen({super.key, required this.runId});

  final int runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final detailsAsync = ref.watch(payrollRunDetailsProvider(runId));
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.payrollRunDetailTitle)),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (details) {
          if (details.isEmpty) {
            return Center(child: Text(t.noPayrollRunsYet));
          }
          final employees = employeesAsync.value ?? const [];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: details.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _PayslipCard(
              detail: details[i],
              employeeName: _employeeName(employees, details[i]['employee_id']),
            ),
          );
        },
      ),
    );
  }

  String? _employeeName(List<Map<String, dynamic>> employees, dynamic employeeId) {
    final match = employees.where((e) => e['id'] == employeeId);
    return match.isNotEmpty ? match.first['name']?.toString() : null;
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({required this.detail, required this.employeeName});

  final Map<String, dynamic> detail;
  final String? employeeName;

  int _n(String key) => (detail[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employeeName ?? 'Employee #${detail['employee_id']}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _row(t.baseSalaryLabel, _n('base_salary')),
            _row(t.overtimePayLabel, _n('overtime_pay')),
            _row(t.leaveDeductionLabel, -_n('leave_deduction')),
            _row(t.allowanceTotalLabel, _n('allowance_total')),
            _row(t.fixedDeductionTotalLabel, -_n('fixed_deduction_total')),
            const Divider(),
            _row(t.netSalaryLabel, _n('net_salary'), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int amount, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatRupiah(amount), style: style),
        ],
      ),
    );
  }
}
