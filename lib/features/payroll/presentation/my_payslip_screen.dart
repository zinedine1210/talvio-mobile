import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/payroll_providers.dart';

/// "Slip gaji saya" — every payslip this employee has across all payroll
/// runs, most recent first (see payroll.Service.MySlips on the backend).
class MyPayslipScreen extends ConsumerWidget {
  const MyPayslipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final slipsAsync = ref.watch(mySlipsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.myPayslipsTitle)),
      body: slipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (slips) {
          if (slips.isEmpty) {
            return Center(child: Text(t.noPayslipsYet));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mySlipsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: slips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final slip = slips[i];
                final net = (slip['net_salary'] as num?)?.toInt() ?? 0;
                return Card(
                  child: ExpansionTile(
                    title: Text(formatRupiah(net),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(t.netSalaryLabel),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row(t.baseSalaryLabel, slip['base_salary']),
                            _row(t.overtimePayLabel, slip['overtime_pay']),
                            _row(t.leaveDeductionLabel, slip['leave_deduction']),
                            _row(t.allowanceTotalLabel, slip['allowance_total']),
                            _row(t.fixedDeductionTotalLabel, slip['fixed_deduction_total']),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, dynamic amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(formatRupiah((amount as num?)?.toInt() ?? 0)),
        ],
      ),
    );
  }
}
