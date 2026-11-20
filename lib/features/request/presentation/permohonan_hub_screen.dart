import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../attendance/attendance_status.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../correction/providers/correction_providers.dart';
import '../../leave/leave_duration.dart';
import '../../leave/providers/leave_providers.dart';
import '../../overtime/providers/overtime_providers.dart';

/// "07 Ajukan Permohonan" — one hub with 3 tabs (figma 07/07b/07c) instead
/// of 3 separate pushed screens. Same submit calls as the old standalone
/// forms (leaveApiProvider / overtimeApiProvider / correctionApiProvider);
/// this only replaces the UI layer, not the data layer.
class PermohonanHubScreen extends StatefulWidget {
  const PermohonanHubScreen({super.key});

  @override
  State<PermohonanHubScreen> createState() => _PermohonanHubScreenState();
}

class _PermohonanHubScreenState extends State<PermohonanHubScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.permohonanHubTitle),
        actions: [
          // Cuma riwayat cuti/izin — overtime & koreksi belum punya layar
          // riwayat personal sendiri di app ini.
          TextButton(
            onPressed: () => context.push('/leave/history'),
            child: Text(t.historyLabel),
          ),
        ],
      ),
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
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: _TabPill(
                          label: [t.tabCutiIzin, t.tabLembur, t.tabKoreksi][i],
                          selected: _tab == i,
                          onTap: () => setState(() => _tab = i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [_LeaveTab(), _OvertimeTab(), _CorrectionTab()],
            ),
          ),
        ],
      ),
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

class _UploadBox extends StatelessWidget {
  const _UploadBox({required this.fileName, required this.onTap});
  final String? fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF99F6E4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(fileName == null ? Icons.upload_file_outlined : Icons.check_circle,
                  color: const Color(0xFF0D9488)),
              const SizedBox(height: 8),
              Text(fileName ?? t.uploadDocumentLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF134E4A), fontSize: 13)),
              const SizedBox(height: 2),
              Text(fileName == null ? t.uploadDocumentHint : t.uploadDocumentReplaceHint,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.event_outlined)),
        child: Text(value),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.access_time)),
        child: Text(value),
      ),
    );
  }
}

class _LeaveTab extends ConsumerStatefulWidget {
  const _LeaveTab();
  @override
  ConsumerState<_LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends ConsumerState<_LeaveTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _type = 'cuti';
  DateTimeRange? _range;
  XFile? _attachment;
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

  Future<void> _pickAttachment() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _attachment = picked);
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_range == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.requiredField)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final created = await ref.read(leaveApiProvider).createLeaveRequest(
            type: _type,
            startDate: fmt(_range!.start),
            endDate: fmt(_range!.end),
            reason: _reasonController.text.trim(),
          );
      if (_attachment != null) {
        final bytes = await File(_attachment!.path).readAsBytes();
        await ref.read(leaveApiProvider).uploadAttachment(
              created['id'] as int,
              bytes,
              _attachment!.name,
            );
      }
      ref.invalidate(myLeaveRequestsProvider);
      ref.invalidate(myLeaveQuotaProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.leaveRequestSubmittedMessage)));
      setState(() {
        _range = null;
        _attachment = null;
        _reasonController.clear();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final quotaAsync = ref.watch(myLeaveQuotaProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            _DateField(
              label: t.dateRangeLabel,
              value: _range == null
                  ? t.selectDateRangeButton
                  : '${formatDateLong(_range!.start)} - ${formatDateLong(_range!.end)}'
                      ' (${leaveDurationDays(_range!.start, _range!.end)})',
              onTap: _pickRange,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              decoration: InputDecoration(labelText: t.reasonLabel),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? t.requiredField : null,
            ),
            const SizedBox(height: 16),
            _UploadBox(fileName: _attachment?.name, onTap: _pickAttachment),
            const SizedBox(height: 16),
            quotaAsync.maybeWhen(
              data: (q) => DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.remainingQuotaLabel,
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                      Text(
                        '${(q['quota_days'] as num? ?? 0) - (q['used_days'] as num? ?? 0)} hari',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A)),
                      ),
                    ],
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t.submitRequestButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _OvertimeTab extends ConsumerStatefulWidget {
  const _OvertimeTab();
  @override
  ConsumerState<_OvertimeTab> createState() => _OvertimeTabState();
}

class _OvertimeTabState extends ConsumerState<_OvertimeTab> {
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
        context: context, firstDate: DateTime(now.year - 1), lastDate: now, initialDate: _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked =
        await showTimePicker(context: context, initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now());
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
      setState(() {
        _startTime = null;
        _endTime = null;
        _reasonController.clear();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateField(label: t.overtimeDateLabel, value: formatDateLong(_date), onTap: _pickDate),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: t.overtimeStartTimeLabel,
                    value: _startTime == null ? t.selectTimeButton : _formatTime(_startTime!),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: t.overtimeEndTimeLabel,
                    value: _endTime == null ? t.selectTimeButton : _formatTime(_endTime!),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
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
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t.submitRequestButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionTab extends ConsumerStatefulWidget {
  const _CorrectionTab();
  @override
  ConsumerState<_CorrectionTab> createState() => _CorrectionTabState();
}

class _CorrectionTabState extends ConsumerState<_CorrectionTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
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
        context: context, firstDate: DateTime(now.year - 1), lastDate: now, initialDate: _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.correctionSubmittedMessage)));
      setState(() {
        _time = null;
        _reasonController.clear();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final attendanceAsync = ref.watch(myAttendanceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateField(label: t.correctionDateLabel, value: formatDateLong(_date), onTap: _pickDate),
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
                  return Text(t.noAttendanceForDateError,
                      style: const TextStyle(color: Color(0xFFDC2626)));
                }
                final clockIn = att['clock_in_at']?.toString();
                final clockOut = att['clock_out_at']?.toString();
                String hhmm(String? iso) {
                  if (iso == null || iso.isEmpty) return '-';
                  final d = DateTime.parse(iso).toLocal();
                  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecoratedBox(
                      decoration:
                          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tercatat sistem',
                                style: TextStyle(color: Color(0xFF475569), fontSize: 13)),
                            Text('${hhmm(clockIn)} - ${hhmm(clockOut)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _field,
                      decoration: InputDecoration(labelText: t.correctionFieldLabel),
                      items: [
                        DropdownMenuItem(value: 'clock_in', child: Text(t.correctionFieldClockIn)),
                        DropdownMenuItem(value: 'clock_out', child: Text(t.correctionFieldClockOut)),
                      ],
                      onChanged: (v) => setState(() => _field = v ?? 'clock_out'),
                    ),
                    const SizedBox(height: 12),
                    _TimeField(
                      label: t.correctionTimeLabel,
                      value: _time == null ? t.selectTimeButton : _formatTime(_time!),
                      onTap: _pickTime,
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
                      onPressed: _isSaving ? null : () => _submit(att['id'] as int),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(t.submitRequestButton),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
