import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/payroll_api.dart';

final payrollApiProvider = Provider<PayrollApi>((ref) => PayrollApi(ref.watch(dioProvider)));

final salaryComponentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(payrollApiProvider).getSalaryComponents();
});

final payrollRunsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(payrollApiProvider).getRuns();
});

final mySlipsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(payrollApiProvider).getMySlips();
});

final employeeSalaryComponentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, employeeId) {
  return ref.watch(payrollApiProvider).getEmployeeSalaryComponents(employeeId);
});

final payrollRunDetailsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, runId) {
  return ref.watch(payrollApiProvider).getRunDetails(runId);
});

/// Employee count + total net pay for one run — derived from the same
/// details endpoint the run-detail screen already uses (no backend
/// employee_count/total_amount field exists on PayrollRun itself).
typedef PayrollRunTotals = ({int employeeCount, int totalNetSalary});

final payrollRunTotalsProvider =
    FutureProvider.autoDispose.family<PayrollRunTotals, int>((ref, runId) async {
  final details = await ref.watch(payrollRunDetailsProvider(runId).future);
  final total = details.fold<int>(0, (sum, d) => sum + ((d['net_salary'] as num?)?.toInt() ?? 0));
  return (employeeCount: details.length, totalNetSalary: total);
});
