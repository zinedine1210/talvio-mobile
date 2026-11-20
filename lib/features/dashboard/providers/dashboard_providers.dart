import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../attendance/attendance_status.dart';
import '../../employee/providers/employee_providers.dart';
import '../../report/providers/report_providers.dart';
import '../data/dashboard_api.dart';

final dashboardApiProvider =
    Provider<DashboardApi>((ref) => DashboardApi(ref.watch(dioProvider)));

final dashboardSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(dashboardApiProvider).getSummary();
});

/// Stat strip pada beranda HR Admin (figma "13 Beranda HR Admin") butuh
/// jumlah karyawan dan jumlah hadir hari ini — keduanya tidak ada di
/// endpoint dashboard/summary, jadi dihitung di sini dari endpoint yang
/// sudah ada (daftar karyawan + laporan absensi rentang hari-ini-saja)
/// daripada menambah endpoint backend baru untuk ini.
final hrDashboardStatsProvider =
    FutureProvider.autoDispose<({int totalEmployees, int presentToday})>((ref) async {
  final employees = await ref.watch(employeeListProvider.future);
  final today = todayDateString();
  final summary = await ref
      .watch(reportApiProvider)
      .getAttendanceSummary(dateFrom: today, dateTo: today);
  final rows = (summary['employees'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final presentToday =
      rows.where((r) => ((r['days_present'] as num?)?.toInt() ?? 0) > 0).length;
  return (totalEmployees: employees.length, presentToday: presentToday);
});
