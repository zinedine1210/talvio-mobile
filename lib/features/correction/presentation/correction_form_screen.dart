import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../attendance/attendance_status.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../providers/correction_providers.dart';

/// Self-service: pick the attendance date, which field is wrong
/// (clock_in/clock_out), and the correct time — approval is always HR
/// (SPEC.md), routed via a separate HR-only review screen, not this form.
class CorrectionFormScreen extends ConsumerStatefulWidget {
  const CorrectionFormScreen({super.key});

  @override
  ConsumerState<CorrectionFormScreen> createState() => _CorrectionFormScreenState();
}

class _CorrectionFormScreenState extends ConsumerState<CorrectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  // "Forgot to clock out" is the case this exists for (SPEC.md), so it's
  // the more useful default — clock_in corrections are the less common case.
  DateTime _date = DateTime.now().subtract(const Duration(days: 1));
  String _field = 'clock_out';
  TimeOfDay? _time;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit(int attendanceId) async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_time == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.requiredField)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(correctionApiProvider).createCorrection(
            attendanceId: attendanceId,
            field: _field,
            time: _formatTime(_time!),
            reason: _reasonController.text.trim(),
          );
      ref.invalidate(myAttendanceProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.correctionSubmittedMessage)));
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
    final attendanceAsync = ref.watch(myAttendanceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.newCorrectionTitle)),
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
                        title: Text(t.correctionDateLabel),
                        subtitle: Text(formatDateLong(_date)),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: _pickDate,
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      attendanceAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Text(translateError(context, e)),
                        data: (records) {
                          final att = findAttendanceForDate(records, _dateString);
                          if (att == null) {
                            return Text(
                              t.noAttendanceForDateError,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            );
                          }
                          return DropdownButtonFormField<String>(
                            initialValue: _field,
                            decoration: InputDecoration(labelText: t.correctionFieldLabel),
                            items: [
                              DropdownMenuItem(
                                  value: 'clock_in', child: Text(t.correctionFieldClockIn)),
                              DropdownMenuItem(
                                  value: 'clock_out', child: Text(t.correctionFieldClockOut)),
                            ],
                            onChanged: (v) => setState(() => _field = v ?? 'clock_out'),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.correctionTimeLabel),
                        subtitle: Text(_time == null ? t.selectTimeButton : _formatTime(_time!)),
                        trailing: const Icon(Icons.access_time_outlined),
                        onTap: _pickTime,
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
              attendanceAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (records) {
                  final att = findAttendanceForDate(records, _dateString);
                  return FilledButton(
                    onPressed: (_isSaving || att == null)
                        ? null
                        : () => _submit(att['id'] as int),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.submitButton),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
