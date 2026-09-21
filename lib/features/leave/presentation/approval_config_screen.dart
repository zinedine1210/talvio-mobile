import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/leave_providers.dart';

/// HR-only: who approves `leave` requests for this company — a direct
/// supervisor, a named delegate, or HR itself. See SPEC.md's approval
/// resolver (also used later by overtime/wfh_review, out of scope here).
class ApprovalConfigScreen extends ConsumerStatefulWidget {
  const ApprovalConfigScreen({super.key});

  @override
  ConsumerState<ApprovalConfigScreen> createState() => _ApprovalConfigScreenState();
}

class _ApprovalConfigScreenState extends ConsumerState<ApprovalConfigScreen> {
  String _mode = 'hr';
  int? _delegateId;
  bool _isSaving = false;
  bool _initialized = false;

  void _applyExisting(List<Map<String, dynamic>> configs) {
    if (_initialized) return;
    final leave = configs.where((c) => c['request_type'] == 'leave');
    if (leave.isNotEmpty) {
      _mode = leave.first['approver_mode']?.toString() ?? 'hr';
      _delegateId = leave.first['delegate_employee_id'] as int?;
    }
    _initialized = true;
  }

  Future<void> _save(List<Map<String, dynamic>> existing) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final others = existing.where((c) => c['request_type'] != 'leave').toList();
      final updated = [
        ...others,
        {
          'request_type': 'leave',
          'approver_mode': _mode,
          if (_mode == 'delegate') 'delegate_employee_id': _delegateId,
        },
      ];
      await ref.read(leaveApiProvider).updateApprovalConfigs(updated);
      ref.invalidate(approvalConfigsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.approvalConfigSavedMessage)));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final configsAsync = ref.watch(approvalConfigsProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.approvalConfigTitle)),
      body: configsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (configs) {
          _applyExisting(configs);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: InputDecoration(labelText: t.approverModeLabel),
                  items: [
                    DropdownMenuItem(value: 'supervisor', child: Text(t.approverModeSupervisor)),
                    DropdownMenuItem(value: 'delegate', child: Text(t.approverModeDelegate)),
                    DropdownMenuItem(value: 'hr', child: Text(t.approverModeHr)),
                  ],
                  onChanged: (v) => setState(() => _mode = v ?? 'hr'),
                ),
                if (_mode == 'delegate') ...[
                  const SizedBox(height: 12),
                  employeesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(translateError(context, e)),
                    data: (employees) => DropdownButtonFormField<int?>(
                      initialValue: _delegateId,
                      decoration: InputDecoration(labelText: t.delegateEmployeeLabel),
                      items: employees
                          .map((e) => DropdownMenuItem(
                                value: e['id'] as int,
                                child: Text(e['name']?.toString() ?? '-'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _delegateId = v),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : () => _save(configs),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(t.saveButton),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
