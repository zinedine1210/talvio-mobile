import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/attendance_providers.dart';

/// "Laporan Absensi Pribadi" (figma "06"): bulan berjalan, strip statistik,
/// dan daftar hari dengan badge status. Baris cuti/izin tidak ikut
/// digabung di sini — `myAttendanceProvider` cuma data presensi, bukan
/// data cuti, jadi kolom itu akan selalu kosong sampai ada endpoint yang
/// menggabungkan keduanya.
class AttendanceReportScreen extends ConsumerStatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  ConsumerState<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends ConsumerState<AttendanceReportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final recordsAsync = ref.watch(myAttendanceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.attendanceReportTitle)),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (records) {
          final monthRecords = records.where((r) {
            final d = DateTime.tryParse(r['date']?.toString() ?? '');
            return d != null && d.year == _month.year && d.month == _month.month;
          }).toList()
            ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

          final hadir = monthRecords.where((r) => r['clock_in_at'] != null).length;
          final terlambat = monthRecords.where((r) => r['is_late'] == true).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PeriodRow(
                label: '${_monthNames[_month.month - 1]} ${_month.year}',
                onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
              const SizedBox(height: 16),
              _StatStrip(hadir: hadir, terlambat: terlambat, izin: 0),
              const SizedBox(height: 16),
              if (monthRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text(t.attendanceReportEmptyMessage)),
                )
              else
                for (final r in monthRecords) _AttendanceRow(record: r),
            ],
          );
        },
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.label, required this.onPrev, required this.onNext});
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
            Expanded(
              child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.hadir, required this.terlambat, required this.izin});
  final int hadir;
  final int terlambat;
  final int izin;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            ],
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            stat('$hadir', t.statHadirLabel),
            stat('$terlambat', t.statTerlambatLabel),
            stat('$izin', t.statIzinLabel),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final date = DateTime.parse(record['date'] as String);
    final isLate = record['is_late'] == true;
    final clockIn = record['clock_in_at']?.toString();
    final clockOut = record['clock_out_at']?.toString();
    final timeRange = clockIn == null
        ? '-'
        : '${_hhmm(clockIn)}${clockOut != null && clockOut.isNotEmpty ? ' - ${_hhmm(clockOut)}' : ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/attendance/record-detail', extra: record),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDayLabel(date), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(timeRange, style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: isLate ? const Color(0xFFFFEDD5) : const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      isLate ? t.statTerlambatLabel : t.onTimeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isLate ? const Color(0xFF9A3412) : const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _hhmm(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static String _formatDayLabel(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_monthShort(d.month)}';
  static const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  static String _monthShort(int m) => _monthsShort[m - 1];
}
