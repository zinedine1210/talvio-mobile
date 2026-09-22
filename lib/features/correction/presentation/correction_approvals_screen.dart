import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/correction_providers.dart';

/// HR-only (route-gated on the backend, and this screen is only reachable
/// from an HR-gated menu item) — corrections are always decided by HR,
/// never routed through the approval resolver like leave/overtime.
class CorrectionApprovalsScreen extends ConsumerWidget {
  const CorrectionApprovalsScreen({super.key});

  String _fieldLabel(AppLocalizations t, String? field) => switch (field) {
        'clock_in' => t.correctionFieldClockIn,
        'clock_out' => t.correctionFieldClockOut,
        _ => field ?? '-',
      };

  Future<void> _act(BuildContext context, WidgetRef ref, int id, bool approve) async {
    final t = AppLocalizations.of(context)!;
    try {
      if (approve) {
        await ref.read(correctionApiProvider).approve(id);
      } else {
        await ref.read(correctionApiProvider).reject(id);
      }
      ref.invalidate(pendingCorrectionsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.correctionApprovalSuccessMessage)));
    } on DioException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final pendingAsync = ref.watch(pendingCorrectionsProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.correctionApprovalsTitle)),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (corrections) {
          if (corrections.isEmpty) {
            return Center(child: Text(t.noCorrectionApprovalsMessage));
          }
          final employees = employeesAsync.value ?? const [];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingCorrectionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: corrections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final c = corrections[i];
                final match = employees.where((e) => e['id'] == c['employee_id']);
                final name = match.isNotEmpty ? match.first['name']?.toString() : null;
                final colorScheme = Theme.of(context).colorScheme;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(Icons.person_outline,
                                  size: 18, color: colorScheme.onPrimaryContainer),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(name ?? 'Employee #${c['employee_id']}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            Chip(
                              label: Text(_fieldLabel(t, c['field']?.toString())),
                              backgroundColor: colorScheme.secondaryContainer,
                              labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${t.requestedTimeLabel}: ${formatDateTimeLong(DateTime.parse(c['requested_time'].toString()))}',
                        ),
                        if ((c['reason'] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(c['reason'].toString()),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _act(context, ref, c['id'] as int, false),
                              child: Text(t.rejectButton),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _act(context, ref, c['id'] as int, true),
                              child: Text(t.approveButton),
                            ),
                          ],
                        ),
                      ],
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
