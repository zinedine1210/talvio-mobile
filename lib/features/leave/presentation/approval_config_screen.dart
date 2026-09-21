import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/leave_providers.dart';

/// HR-only: who approves each request type for this company — a direct
/// supervisor, a named delegate, or HR itself. See SPEC.md's approval
/// resolver. `overtime` isn't configurable here yet (that fase hasn't
/// landed), but any existing config for it is preserved on save.
class ApprovalConfigScreen extends ConsumerStatefulWidget {
  const ApprovalConfigScreen({super.key});

  @override
  ConsumerState<ApprovalConfigScreen> createState() => _ApprovalConfigScreenState();
}

class _TypeConfig {
  String mode = 'hr';
  int? delegateId;
}

class _ApprovalConfigScreenState extends ConsumerState<ApprovalConfigScreen> {
  final _configs = {'leave': _TypeConfig(), 'wfh_review': _TypeConfig()};
  bool _isSaving = false;
  bool _initialized = false;

  void _applyExisting(List<Map<String, dynamic>> configs) {
    if (_initialized) return;
    for (final entry in _configs.entries) {
      final match = configs.where((c) => c['request_type'] == entry.key);
      if (match.isNotEmpty) {
        entry.value.mode = match.first['approver_mode']?.toString() ?? 'hr';
        entry.value.delegateId = match.first['delegate_employee_id'] as int?;
      }
    }
    _initialized = true;
  }

  Future<void> _save(List<Map<String, dynamic>> existing) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final others = existing.where((c) => !_configs.containsKey(c['request_type'])).toList();
      final updated = [
        ...others,
        for (final entry in _configs.entries)
          {
            'request_type': entry.key,
            'approver_mode': entry.value.mode,
            if (entry.value.mode == 'delegate') 'delegate_employee_id': entry.value.delegateId,
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

  Widget _section(String title, _TypeConfig config, List<Map<String, dynamic>> employees) {
    final t = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: config.mode,
              decoration: InputDecoration(labelText: t.approverModeLabel),
              items: [
                DropdownMenuItem(value: 'supervisor', child: Text(t.approverModeSupervisor)),
                DropdownMenuItem(value: 'delegate', child: Text(t.approverModeDelegate)),
                DropdownMenuItem(value: 'hr', child: Text(t.approverModeHr)),
              ],
              onChanged: (v) => setState(() => config.mode = v ?? 'hr'),
            ),
            if (config.mode == 'delegate') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: config.delegateId,
                decoration: InputDecoration(labelText: t.delegateEmployeeLabel),
                items: employees
                    .map((e) => DropdownMenuItem(
                          value: e['id'] as int,
                          child: Text(e['name']?.toString() ?? '-'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => config.delegateId = v),
              ),
            ],
          ],
        ),
      ),
    );
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
          return employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(translateError(context, e))),
            data: (employees) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _section(t.approvalConfigLeaveLabel, _configs['leave']!, employees),
                  const SizedBox(height: 16),
                  _section(t.approvalConfigWfhReviewLabel, _configs['wfh_review']!, employees),
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
            ),
          );
        },
      ),
    );
  }
}
