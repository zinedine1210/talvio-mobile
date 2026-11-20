import 'package:dio/dio.dart';

class PayrollApi {
  PayrollApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getSalaryComponents() async {
    final res = await _dio.get('/payroll/salary-components');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createSalaryComponent({
    required String name,
    required String type,
    required String amountType,
    required int amount,
  }) async {
    final res = await _dio.post('/payroll/salary-components', data: {
      'name': name,
      'type': type,
      'amount_type': amountType,
      'amount': amount,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEmployeeSalary(int employeeId, int baseSalary) async {
    final res = await _dio.put('/employees/$employeeId/salary', data: {'base_salary': baseSalary});
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getEmployeeSalaryComponents(int employeeId) async {
    final res = await _dio.get('/employees/$employeeId/salary-components');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> assignSalaryComponent(int employeeId, int salaryComponentId, {int? customAmount}) async {
    await _dio.post('/employees/$employeeId/salary-components', data: {
      'salary_component_id': salaryComponentId,
      if (customAmount != null) 'custom_amount': customAmount,
    });
  }

  Future<void> removeEmployeeSalaryComponent(int employeeId, int assignmentId) async {
    await _dio.delete('/employees/$employeeId/salary-components/$assignmentId');
  }

  Future<Map<String, dynamic>> generateRun() async {
    final res = await _dio.post('/payroll/runs');
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRuns() async {
    final res = await _dio.get('/payroll/runs');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getRunDetails(int runId) async {
    final res = await _dio.get('/payroll/runs/$runId/details');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getMySlips() async {
    final res = await _dio.get('/payroll/slips/me');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getEmployeeSlips(int employeeId) async {
    final res = await _dio.get('/payroll/slips/$employeeId');
    return (res.data as List).cast<Map<String, dynamic>>();
  }
}
