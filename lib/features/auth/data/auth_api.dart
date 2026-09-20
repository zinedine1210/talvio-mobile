import 'package:dio/dio.dart';

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> registerCompany({
    required String companyName,
    required String adminName,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/register-company', data: {
      'company_name': companyName,
      'admin_name': adminName,
      'email': email,
      'password': password,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return res.data as Map<String, dynamic>;
  }
}
