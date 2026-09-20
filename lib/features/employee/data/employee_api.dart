import 'package:dio/dio.dart';

class EmployeeApi {
  EmployeeApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> listEmployees() async {
    final res = await _dio.get('/employees');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getEmployee(int id) async {
    final res = await _dio.get('/employees/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/employees/me');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> payload) async {
    final res = await _dio.post('/employees', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEmployee(int id, Map<String, dynamic> payload) async {
    final res = await _dio.put('/employees/$id', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deactivateEmployee(int id) async {
    await _dio.delete('/employees/$id');
  }

  Future<List<Map<String, dynamic>>> listDepartments() async {
    final res = await _dio.get('/departments');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createDepartment(String name) async {
    final res = await _dio.post('/departments', data: {'name': name});
    return res.data as Map<String, dynamic>;
  }
}
