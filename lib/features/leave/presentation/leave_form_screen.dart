import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../leave_duration.dart';
import '../providers/leave_providers.dart';

class LeaveFormScreen extends ConsumerStatefulWidget {
  const LeaveFormScreen({super.key});

  @override
  ConsumerState<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends ConsumerState<LeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _type = 'cuti';
  DateTimeRange? _range;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_range == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.requiredField)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      await ref.read(leaveApiProvider).createLeaveRequest(
            type: _type,
            startDate: fmt(_range!.start),
            endDate: fmt(_range!.end),
            reason: _reasonController.text.trim(),
          );
      ref.invalidate(myLeaveRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.leaveRequestSubmittedMessage)));
      context.pop();
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
    final quotaAsync = ref.watch(myLeaveQuotaProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.newLeaveRequestTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              quotaAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (q) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${t.remainingQuotaLabel}: ${t.quotaDaysUsedFormat(q['used_days'] as int? ?? 0, q['quota_days'] as int? ?? 0)}',
                  ),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(labelText: t.leaveTypeLabel),
                items: [
                  DropdownMenuItem(value: 'cuti', child: Text(t.leaveTypeCuti)),
                  DropdownMenuItem(value: 'izin', child: Text(t.leaveTypeIzin)),
                  DropdownMenuItem(value: 'sakit', child: Text(t.leaveTypeSakit)),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'cuti'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.dateRangeLabel),
                subtitle: Text(_range == null
                    ? t.selectDateRangeButton
                    : '${_range!.start.toString().split(' ').first} — '
                        '${_range!.end.toString().split(' ').first} '
                        '(${leaveDurationDays(_range!.start, _range!.end)})'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickRange,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(labelText: t.reasonLabel),
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? t.requiredField : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(t.submitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
