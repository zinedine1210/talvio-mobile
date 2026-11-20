import 'package:dio/dio.dart';

class DashboardApi {
  DashboardApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getSummary() async {
    final res = await _dio.get('/dashboard/summary');
    return res.data as Map<String, dynamic>;
  }
}
