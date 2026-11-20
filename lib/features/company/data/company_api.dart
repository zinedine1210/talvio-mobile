import 'package:dio/dio.dart';

class CompanyApi {
  CompanyApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/company/me');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> payload) async {
    final res = await _dio.put('/company/settings', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> payload) async {
    final res = await _dio.post('/company/locations', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLocation(int id, Map<String, dynamic> payload) async {
    final res = await _dio.put('/company/locations/$id', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deactivateLocation(int id) async {
    await _dio.delete('/company/locations/$id');
  }
}
