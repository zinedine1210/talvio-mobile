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
              padding: const EdgeInsets.all(24),
              itemCount: slips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 20),
              itemBuilder: (context, i) => _SlipCard(slip: slips[i]),
            ),
          );
        },
      ),
    );
  }
}

class _SlipCard extends StatelessWidget {
  const _SlipCard({required this.slip});
  final Map<String, dynamic> slip;

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final net = _int(slip['net_salary']);
    final base = _int(slip['base_salary']);
    final overtime = _int(slip['overtime_pay']);
    final allowance = _int(slip['allowance_total']);
    final leaveDeduction = _int(slip['leave_deduction']);
    final fixedDeduction = _int(slip['fixed_deduction_total']);
    final periodStart = DateTime.tryParse(slip['period_start']?.toString() ?? '');

    Widget row(String label, int amount, {bool negative = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
              Text(
                '${negative ? '-' : ''}${formatRupiah(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: negative ? const Color(0xFFDC2626) : const Color(0xFF134E4A),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (periodStart != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(formatMonthYear(periodStart),
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF134E4A))),
          ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.netSalaryLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              Text(formatRupiah(net),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.earningsCardTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
                const SizedBox(height: 12),
                row(t.baseSalaryLabel, base),
                if (overtime > 0) row(t.overtimePayLabel, overtime),
                if (allowance > 0) row(t.allowanceTotalLabel, allowance),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.deductionsCardTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
                const SizedBox(height: 12),
                if (fixedDeduction > 0) row(t.fixedDeductionTotalLabel, fixedDeduction, negative: true),
                if (leaveDeduction > 0) row(t.leaveDeductionLabel, leaveDeduction, negative: true),
                if (fixedDeduction == 0 && leaveDeduction == 0)
                  Text(t.noDeductionLabel, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
