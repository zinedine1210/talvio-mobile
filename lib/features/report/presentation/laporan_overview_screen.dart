import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/report_providers.dart';

/// "17 Laporan" (HR) — company-wide month overview: StatStrip (Hadir/
/// Terlambat/Izin, same pattern+labels as the employee's own
/// AttendanceReportScreen) + attendance rate per department (computed
/// client-side from AttendanceSummary + employeeListProvider — no backend
/// per-department aggregate exists) + export. Izin stays 0, same
/// documented limitation as the employee screen (attendance data has no
/// leave join). Figma's own "17b Detail Laporan Departemen" drill-down is
/// broken/mismatched content (correction-review copy), same pattern as
/// other flows this session — not implemented; the existing, richer
/// ReportsScreen (date range, per-employee filter, leave tab) stays
/// reachable via a link instead of being replaced.
class LaporanOverviewScreen extends ConsumerStatefulWidget {
  const LaporanOverviewScreen({super.key});

  @override
  ConsumerState<LaporanOverviewScreen> createState() => _LaporanOverviewScreenState();
}

class _LaporanOverviewScreenState extends ConsumerState<LaporanOverviewScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _summary;
  bool _isLoading = false;
  bool _isExporting = false;

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime get _monthStart => DateTime(_month.year, _month.month, 1);
  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1, 0);

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(reportApiProvider).getAttendanceSummary(
            dateFrom: _fmtDate(_monthStart),
            dateTo: _fmtDate(_monthEnd),
          );
      if (mounted) setState(() => _summary = data);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _export(String format) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isExporting = true);
    try {
      final file = await ref.read(reportApiProvider).exportAttendanceSummary(
            dateFrom: _fmtDate(_monthStart),
            dateTo: _fmtDate(_monthEnd),
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

  Future<void> _pickExportFormat() async {
    final t = AppLocalizations.of(context)!;
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(t.reportsExportPdfButton),
              onTap: () => context.pop('pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(t.reportsExportXlsxButton),
              onTap: () => context.pop('xlsx'),
            ),
          ],
        ),
      ),
    );
    if (format != null) await _export(format);
  }

  int _workingDaysInMonth() {
    var count = 0;
    for (var d = _monthStart; !d.isAfter(_monthEnd); d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final employeesAsync = ref.watch(employeeListProvider);
    final departmentsAsync = ref.watch(departmentListProvider);
    final rows = (_summary?['employees'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    final presentById = <int, int>{};
    var totalPresent = 0;
    var totalLate = 0;
    for (final r in rows) {
      final id = (r['employee_id'] as num?)?.toInt();
      final present = (r['days_present'] as num?)?.toInt() ?? 0;
      if (id != null) presentById[id] = present;
      totalPresent += present;
      totalLate += (r['days_late'] as num?)?.toInt() ?? 0;
    }

    final employees = employeesAsync.value ?? const <Map<String, dynamic>>[];
    final departments = departmentsAsync.value ?? const <Map<String, dynamic>>[];
    final workingDays = _workingDaysInMonth();
    final deptRates = <String, int>{};
    for (final dept in departments) {
      final deptId = dept['id'] as int;
      final deptEmployees = employees.where((e) => e['department_id'] == deptId).toList();
      if (deptEmployees.isEmpty || workingDays == 0) continue;
      final avgPresent = deptEmployees.fold<int>(0, (sum, e) {
            final id = (e['id'] as num?)?.toInt();
            return sum + (id != null ? (presentById[id] ?? 0) : 0);
          }) /
          deptEmployees.length;
      deptRates[dept['name']?.toString() ?? '-'] = ((avgPresent / workingDays) * 100).round();
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.reportsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                  Expanded(
                    child: Text('${_monthNames[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()))
          else ...[
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _stat('$totalPresent', t.statHadirLabel),
                    _stat('$totalLate', t.statTerlambatLabel),
                    _stat('0', t.statIzinLabel),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(t.attendanceRateByDeptLabel,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: deptRates.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t.noDepartmentsYet, style: const TextStyle(color: Color(0xFF475569))),
                    )
                  : Column(
                      children: [
                        for (final entry in deptRates.entries) ...[
                          if (entry.key != deptRates.entries.first.key)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(entry.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, color: Color(0xFF134E4A))),
                                ),
                                Text('${entry.value}%',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, color: Color(0xFF0D9488))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isExporting ? null : _pickExportFormat,
            icon: _isExporting
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share, size: 18),
            label: Text(t.exportReportButton),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.push('/reports/detail'),
              child: Text(t.reportsDetailLinkLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          ],
        ),
      );
}
