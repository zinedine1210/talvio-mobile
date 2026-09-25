import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../attendance/attendance_status.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/report_providers.dart';

/// One endpoint each on the backend serves both "my own report" and HR's
/// company-wide view (SPEC.md) — this screen mirrors that: the employee
/// filter only appears for HR, everyone else always sees just themselves.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.reportsTitle),
          bottom: TabBar(tabs: [
            Tab(text: t.reportsAttendanceTab),
            Tab(text: t.reportsLeaveTab),
          ]),
        ),
        body: const TabBarView(
          children: [_AttendanceReportTab(), _LeaveReportTab()],
        ),
      ),
    );
  }
}

class _EmployeeFilter extends ConsumerWidget {
  const _EmployeeFilter({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final me = ref.watch(currentEmployeeProvider);
    if (me?['role'] != 'hr_admin') return const SizedBox.shrink();
    final employeesAsync = ref.watch(employeeListProvider);
    final employees = employeesAsync.value ?? const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int?>(
        initialValue: value,
        decoration: InputDecoration(labelText: t.reportsEmployeeFilterLabel),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(t.reportsAllEmployeesOption)),
          ...employees.map((e) => DropdownMenuItem<int?>(
                value: e['id'] as int,
                child: Text(e['name']?.toString() ?? '-'),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _AttendanceReportTab extends ConsumerStatefulWidget {
  const _AttendanceReportTab();

  @override
  ConsumerState<_AttendanceReportTab> createState() => _AttendanceReportTabState();
}

class _AttendanceReportTabState extends ConsumerState<_AttendanceReportTab> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  int? _employeeId;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>>? _myRecords;
  bool _isLoading = false;
  bool _isExporting = false;

  bool get _isHr => ref.read(currentEmployeeProvider)?['role'] == 'hr_admin';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  // HR gets the existing company-wide aggregate (counts per employee).
  // Everyone else gets their own day-by-day breakdown instead — SPEC.md's
  // personal report is "what did I do each day", not a count summary.
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      if (_isHr) {
        final data = await ref.read(reportApiProvider).getAttendanceSummary(
              dateFrom: _fmtDate(_range.start),
              dateTo: _fmtDate(_range.end),
              employeeId: _employeeId,
            );
        if (mounted) setState(() => _result = data);
      } else {
        final records = await ref.read(attendanceApiProvider).getMyAttendance();
        if (mounted) setState(() => _myRecords = records);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _export(String format) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isExporting = true);
    try {
      final file = await ref.read(reportApiProvider).exportAttendanceSummary(
            dateFrom: _fmtDate(_range.start),
            dateTo: _fmtDate(_range.end),
            employeeId: _employeeId,
            format: format,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.reportExportSavedMessage(file.path))));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isHr = _isHr;
    final rows = (_result?['employees'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EmployeeFilter(value: _employeeId, onChanged: (v) => setState(() => _employeeId = v)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.dateRangeLabel),
            subtitle: Text('${formatDateLong(_range.start)} — ${formatDateLong(_range.end)}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickRange,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoading ? null : _load,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t.reportsLoadButton),
          ),
          if (isHr && rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: [
                DataColumn(label: Text(t.reportsColumnEmployee)),
                DataColumn(label: Text(t.reportsColumnPresent)),
                DataColumn(label: Text(t.reportsColumnLate)),
                DataColumn(label: Text(t.reportsColumnPendingReview)),
                DataColumn(label: Text(t.reportsColumnMissingClockout)),
                DataColumn(label: Text(t.reportsColumnRejected)),
              ], rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text('#${r['employee_id']}')),
                    DataCell(Text('${r['days_present']}')),
                    DataCell(Text('${r['days_late']}')),
                    DataCell(Text('${r['days_pending_review']}')),
                    DataCell(Text('${r['days_missing_clockout']}')),
                    DataCell(Text('${r['days_rejected']}')),
                  ]),
              ]),
            ),
          ],
          if (!isHr && _myRecords != null) ...[
            const SizedBox(height: 20),
            _DailyAttendanceTable(range: _range, records: _myRecords!),
          ],
          if ((isHr && rows.isNotEmpty) || (!isHr && _myRecords != null)) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isExporting ? null : () => _export('pdf'),
                  child: Text(t.reportsExportPdfButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isExporting ? null : () => _export('xlsx'),
                  child: Text(t.reportsExportXlsxButton),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Per-day breakdown for one employee's own attendance — one row per
/// calendar day in the picked range (not just days with a record), so a
/// missing day reads as [attendanceNoRecordLabel] instead of silently not
/// appearing at all.
class _DailyAttendanceTable extends StatelessWidget {
  const _DailyAttendanceTable({required this.range, required this.records});

  final DateTimeRange range;
  final List<Map<String, dynamic>> records;

  String _timeOrDash(Object? iso) {
    if (iso == null || iso.toString().isEmpty) return '-';
    final d = DateTime.tryParse(iso.toString())?.toLocal();
    if (d == null) return '-';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  ({String label, Color color}) _dayStatus(Map<String, dynamic>? r, AppLocalizations t) {
    if (r == null) return (label: t.attendanceNoRecordLabel, color: AppColors.statusNeutral);
    final status = r['status']?.toString();
    final isLate = r['is_late'] == true;
    return switch (status) {
      'pending_review' => (label: t.reportsColumnPendingReview, color: AppColors.statusWarning),
      'approved_wfh' => (label: t.attendanceApprovedWfhLabel, color: AppColors.statusInfo),
      'rejected' => (label: t.reportsColumnRejected, color: AppColors.statusDanger),
      'missing_clockout' => (label: t.reportsColumnMissingClockout, color: AppColors.statusDanger),
      _ => isLate
          ? (label: t.reportsColumnLate, color: AppColors.statusWarning)
          : (label: t.reportsColumnPresent, color: AppColors.statusSuccess),
    };
  }

  DataRow _buildRow(BuildContext context, DateTime day) {
    final t = AppLocalizations.of(context)!;
    final record = findAttendanceForDate(records, _fmtDate(day));
    final status = _dayStatus(record, t);
    final photoUrl = record?['clock_in_photo_url']?.toString();
    return DataRow(
      onSelectChanged:
          record == null ? null : (_) => context.push('/attendance/record-detail', extra: record),
      cells: [
        DataCell(Text(formatDateLong(day))),
        DataCell(Text(_timeOrDash(record?['clock_in_at']))),
        DataCell(Text(_timeOrDash(record?['clock_out_at']))),
        DataCell(
          photoUrl != null && photoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(photoUrl, width: 36, height: 36, fit: BoxFit.cover),
                )
              : Icon(Icons.image_not_supported_outlined, size: 20, color: Theme.of(context).colorScheme.outline),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status.label,
                style: TextStyle(color: status.color, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final days = <DateTime>[
      for (var d = range.start; !d.isAfter(range.end); d = d.add(const Duration(days: 1))) d,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(t.reportsColumnDate)),
          DataColumn(label: Text(t.clockInTimeLabel)),
          DataColumn(label: Text(t.clockOutTimeLabel)),
          DataColumn(label: Text(t.clockInPhotoLabel)),
          DataColumn(label: Text(t.statusLabel)),
        ],
        rows: [for (final day in days) _buildRow(context, day)],
      ),
    );
  }
}

class _LeaveReportTab extends ConsumerStatefulWidget {
  const _LeaveReportTab();

  @override
  ConsumerState<_LeaveReportTab> createState() => _LeaveReportTabState();
}

class _LeaveReportTabState extends ConsumerState<_LeaveReportTab> {
  int _year = DateTime.now().year;
  int? _employeeId;
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  bool _isExporting = false;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await ref.read(reportApiProvider).getLeaveSummary(year: _year, employeeId: _employeeId);
      if (mounted) setState(() => _result = data);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _export(String format) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isExporting = true);
    try {
      final file = await ref
          .read(reportApiProvider)
          .exportLeaveSummary(year: _year, employeeId: _employeeId, format: format);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.reportExportSavedMessage(file.path))));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final rows = (_result?['employees'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final now = DateTime.now();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EmployeeFilter(value: _employeeId, onChanged: (v) => setState(() => _employeeId = v)),
          DropdownButtonFormField<int>(
            initialValue: _year,
            decoration: InputDecoration(labelText: t.reportsYearLabel),
            items: [
              for (var y = now.year; y >= now.year - 3; y--)
                DropdownMenuItem(value: y, child: Text('$y')),
            ],
            onChanged: (v) => setState(() => _year = v ?? now.year),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoading ? null : _load,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t.reportsLoadButton),
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: [
                DataColumn(label: Text(t.reportsColumnEmployee)),
                DataColumn(label: Text(t.reportsColumnCutiUsed)),
                DataColumn(label: Text(t.reportsColumnCutiQuota)),
                DataColumn(label: Text(t.reportsColumnIzin)),
                DataColumn(label: Text(t.reportsColumnSakit)),
              ], rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text('#${r['employee_id']}')),
                    DataCell(Text('${r['cuti_used_days']}')),
                    DataCell(Text('${r['cuti_quota_days']}')),
                    DataCell(Text('${r['izin_days']}')),
                    DataCell(Text('${r['sakit_days']}')),
                  ]),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isExporting ? null : () => _export('pdf'),
                  child: Text(t.reportsExportPdfButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isExporting ? null : () => _export('xlsx'),
                  child: Text(t.reportsExportXlsxButton),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
