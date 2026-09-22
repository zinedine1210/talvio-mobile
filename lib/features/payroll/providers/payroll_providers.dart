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
