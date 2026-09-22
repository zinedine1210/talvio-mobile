import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/overtime_providers.dart';

/// SPEC.md: overtime is claimed AFTER the fact, against the day's actual
/// clock_out_at — not planned in advance. Defaults to today since that's
/// the normal case (clock out, then immediately claim).
class OvertimeFormScreen extends ConsumerStatefulWidget {
  const OvertimeFormScreen({super.key});

  @override
  ConsumerState<OvertimeFormScreen> createState() => _OvertimeFormScreenState();
}

class _OvertimeFormScreenState extends ConsumerState<OvertimeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.requiredField)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final dateStr =
          '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      await ref.read(overtimeApiProvider).createOvertimeRequest(
            date: dateStr,
            startTime: _formatTime(_startTime!),
            endTime: _formatTime(_endTime!),
            reason: _reasonController.text.trim(),
          );
      ref.invalidate(myOvertimeRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.overtimeRequestSubmittedMessage)));
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

    return Scaffold(
      appBar: AppBar(title: Text(t.newOvertimeRequestTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.overtimeDateLabel),
                        subtitle: Text(formatDateLong(_date)),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.overtimeStartTimeLabel),
                        subtitle: Text(
                            _startTime == null ? t.selectTimeButton : _formatTime(_startTime!)),
                        trailing: const Icon(Icons.access_time_outlined),
                        onTap: () => _pickTime(true),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.overtimeEndTimeLabel),
                        subtitle:
                            Text(_endTime == null ? t.selectTimeButton : _formatTime(_endTime!)),
                        trailing: const Icon(Icons.access_time_outlined),
                        onTap: () => _pickTime(false),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonController,
                        decoration: InputDecoration(labelText: t.reasonLabel),
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.requiredField : null,
                      ),
                    ],
                  ),
                ),
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
