import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/overtime_providers.dart';

/// Requests awaiting the logged-in user's decision — visible to anyone,
/// not just HR, since the approval resolver can route overtime to a plain
/// supervisor or a delegate (same as leave).
class OvertimeApprovalsScreen extends ConsumerWidget {
  const OvertimeApprovalsScreen({super.key});

  Future<void> _act(BuildContext context, WidgetRef ref, int id, bool approve) async {
    final t = AppLocalizations.of(context)!;
    try {
      if (approve) {
        await ref.read(overtimeApiProvider).approve(id);
      } else {
        await ref.read(overtimeApiProvider).reject(id);
      }
      ref.invalidate(overtimeApprovalsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.overtimeApprovalSuccessMessage)));
    } on DioException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(overtimeApprovalsProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.overtimeApprovalsTitle)),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(child: Text(t.noOvertimeApprovalsMessage));
          }
          final employees = employeesAsync.value ?? const [];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(overtimeApprovalsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = requests[i];
                final match = employees.where((e) => e['id'] == r['employee_id']);
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name ?? 'Employee #${r['employee_id']}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                      '${formatDateLongFromString(r['date']?.toString())} · '
                                      '${r['start_time']} — ${r['end_time']}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if ((r['reason'] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(r['reason'].toString()),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _act(context, ref, r['id'] as int, false),
                              child: Text(t.rejectButton),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _act(context, ref, r['id'] as int, true),
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
