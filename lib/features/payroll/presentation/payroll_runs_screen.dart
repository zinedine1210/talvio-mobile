import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/payroll_providers.dart';

/// HR-only: list payroll runs, generate a new one for the period that just
/// closed (server-computed from company.payroll_cutoff_day — no date
/// picker here, see talvio-backend's payroll.payrollPeriod).
class PayrollRunsScreen extends ConsumerStatefulWidget {
  const PayrollRunsScreen({super.key});

  @override
  ConsumerState<PayrollRunsScreen> createState() => _PayrollRunsScreenState();
}

class _PayrollRunsScreenState extends ConsumerState<PayrollRunsScreen> {
  bool _isGenerating = false;

  Future<void> _generate() async {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final runsAsync = ref.watch(payrollRunsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.payrollRunsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _generate,
        icon: _isGenerating
            ? const SizedBox(
                height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.play_arrow),
        label: Text(t.generatePayrollRunButton),
      ),
      body: runsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (runs) {
          if (runs.isEmpty) {
            return Center(child: Text(t.noPayrollRunsYet));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(payrollRunsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: runs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final run = runs[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.payments_outlined, color: colorScheme.onPrimaryContainer),
                    ),
                    title: Text(
                        '${formatDateLongFromString(run['period_start']?.toString())} — '
                        '${formatDateLongFromString(run['period_end']?.toString())}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${t.payDateLabel}: ${formatDateLongFromString(run['pay_date']?.toString())}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/payroll/runs/${run['id']}'),
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
