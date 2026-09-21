import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/leave_providers.dart';

/// Requests awaiting the logged-in user's decision — visible to anyone,
/// not just HR, since the approval resolver can route to a plain
/// supervisor or a delegate (see SPEC.md's approval_configs).
class LeaveApprovalsScreen extends ConsumerWidget {
  const LeaveApprovalsScreen({super.key});

  Future<void> _act(BuildContext context, WidgetRef ref, int id, bool approve) async {
    final t = AppLocalizations.of(context)!;
    try {
      if (approve) {
        await ref.read(leaveApiProvider).approve(id);
      } else {
        await ref.read(leaveApiProvider).reject(id);
      }
      ref.invalidate(leaveApprovalsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.leaveApprovalSuccessMessage)));
    } on DioException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(leaveApprovalsProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.leaveApprovalsTitle)),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(child: Text(t.noLeaveApprovalsMessage));
          }
          final employees = employeesAsync.value ?? const [];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leaveApprovalsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = requests[i];
                final match = employees.where((e) => e['id'] == r['employee_id']);
                final name = match.isNotEmpty ? match.first['name']?.toString() : null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name ?? 'Employee #${r['employee_id']}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('${r['type']} · ${r['start_date']} — ${r['end_date']}'),
                        if ((r['reason'] as String?)?.isNotEmpty == true)
                          Text(r['reason'].toString()),
                        const SizedBox(height: 8),
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
