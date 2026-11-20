import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/payroll_providers.dart';

/// "16 Payroll" — figma's 2 tabs are Payroll run/Komponen gaji. Payroll run
/// tab shows a SummaryCard for the latest run (count/total derived via
/// payrollRunTotalsProvider — no backend employee_count/total_amount field
/// exists) + history list + "Buat payroll run baru". Komponen gaji tab
/// reskins salary_components_screen's content into Tunjangan/Potongan
/// sections. Figma's own edit screens for this flow (16c/16e/16f) are
/// broken/mismatched content, same pattern as Data Karyawan — not
/// implemented; the existing add-component dialog and run-detail push
/// target stay as-is (already functionally correct).
class PayrollHubScreen extends ConsumerStatefulWidget {
  const PayrollHubScreen({super.key});

  @override
  ConsumerState<PayrollHubScreen> createState() => _PayrollHubScreenState();
}

class _PayrollHubScreenState extends ConsumerState<PayrollHubScreen> {
  int _tab = 0;
  bool _isGenerating = false;

  Future<void> _generateRun() async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isGenerating = true);
    try {
      final result = await ref.read(payrollApiProvider).generateRun();
      ref.invalidate(payrollRunsProvider);
      if (!mounted) return;
      final pending = (result['pending_warning'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(pending > 0
            ? t.payrollRunGeneratedWithWarningMessage(pending)
            : t.payrollRunGeneratedMessage),
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _addComponent() async {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  Widget _statusPill(String status, {required bool big}) {
    final color = status == 'draft' ? const Color(0xFFEA580C) : const Color(0xFF0D9488);
    final bg = status == 'draft' ? const Color(0xFFFFEDD5) : const Color(0xFFCCFBF1);
    final t = AppLocalizations.of(context)!;
    final label = status == 'draft'
        ? t.payrollStatusDraftLabel
        : (big ? t.payrollStatusProcessedLabel : t.payrollStatusDoneLabel);
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: big ? 8 : 6),
        child: Text(label,
            style: TextStyle(
                fontSize: big ? 13 : 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.payrollHubTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        child: _TabPill(
                          label: [t.tabPayrollRun, t.tabKomponenGaji][i],
                          selected: _tab == i,
                          onTap: () => setState(() => _tab = i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _tab == 1 ? _buildComponents(t) : _buildRuns(t)),
        ],
      ),
    );
  }

  Widget _buildRuns(AppLocalizations t) {
    final runsAsync = ref.watch(payrollRunsProvider);

    return runsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(translateError(context, e))),
      data: (runs) {
        if (runs.isEmpty) {
          return Center(child: Text(t.noPayrollRunsYet));
        }
        final latest = runs.first;
        final latestTotalsAsync = ref.watch(payrollRunTotalsProvider(latest['id'] as int));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(payrollRunsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.payrollHubTitle} ${formatMonthYear(DateTime.parse(latest['period_end'].toString()))}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      latestTotalsAsync.when(
                        loading: () => const SizedBox(
                            height: 28, width: 28, child: CircularProgressIndicator(color: Colors.white)),
                        error: (_, _) => const Text('-', style: TextStyle(color: Colors.white)),
                        data: (totals) => Text(
                          formatRupiah(totals.totalNetSalary),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _statusPill(latest['status']?.toString() ?? 'draft', big: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(t.payrollHistoryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: runs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final run = runs[i];
                    final runId = run['id'] as int;
                    final totalsAsync = ref.watch(payrollRunTotalsProvider(runId));
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(formatMonthYear(DateTime.parse(run['period_end'].toString())),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF134E4A))),
                      subtitle: totalsAsync.when(
                        loading: () => const Text('-'),
                        error: (_, _) => const Text('-'),
                        data: (totals) => Text(t.payrollEmployeeCountLabel(totals.employeeCount),
                            style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                      ),
                      trailing: _statusPill(run['status']?.toString() ?? 'draft', big: false),
                      onTap: () => context.push('/payroll/runs/$runId'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isGenerating ? null : _generateRun,
                child: _isGenerating
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(t.generatePayrollRunButton),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComponents(AppLocalizations t) {
    final componentsAsync = ref.watch(salaryComponentsProvider);

    return componentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(translateError(context, e))),
      data: (components) {
        final allowances = components.where((c) => c['type'] == 'allowance').toList();
        final deductions = components.where((c) => c['type'] == 'deduction').toList();

        Widget componentRow(Map<String, dynamic> c) {
          final isPercentage = c['amount_type'] == 'percentage';
          final amount = (c['amount'] as num?)?.toInt() ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(c['name']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF134E4A))),
                ),
                Text(isPercentage ? '$amount%' : formatRupiah(amount),
                    style: const TextStyle(color: Color(0xFF475569))),
              ],
            ),
          );
        }

        Widget section(String label, List<Map<String, dynamic>> items) {
          if (items.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        componentRow(items[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(salaryComponentsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              InkWell(
                onTap: _addComponent,
                borderRadius: BorderRadius.circular(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: Color(0xFF0D9488), size: 18),
                        const SizedBox(width: 10),
                        Text(t.addSalaryComponentRowLabel,
                            style:
                                const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (components.isEmpty)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 40), child: Text(t.noSalaryComponentsYet)))
              else ...[
                section(t.salaryComponentAllowance, allowances),
                section(t.salaryComponentDeduction, deductions),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D9488) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
