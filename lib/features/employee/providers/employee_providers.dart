import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/employee_api.dart';

final employeeApiProvider = Provider<EmployeeApi>((ref) => EmployeeApi(ref.watch(dioProvider)));

final employeeListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(employeeApiProvider).listEmployees();
});

final departmentListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(employeeApiProvider).listDepartments();
});

final myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(employeeApiProvider).getMe();
});

final locationListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(employeeApiProvider).listLocations();
});
