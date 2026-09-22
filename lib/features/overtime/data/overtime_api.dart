import 'package:dio/dio.dart';

class OvertimeApi {
  OvertimeApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> createOvertimeRequest({
    required String date,
    required String startTime,
    required String endTime,
    required String reason,
  }) async {
    final res = await _dio.post('/overtime-requests', data: {
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyOvertimeRequests() async {
    final res = await _dio.get('/overtime-requests/me');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Requests awaiting the logged-in user's decision — same resolver-based
  /// routing as leave (a plain supervisor or delegate, not just HR).
  Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    final res = await _dio.get('/overtime-requests');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> approve(int id) async {
    await _dio.post('/overtime-requests/$id/approve');
  }

  Future<void> reject(int id) async {
    await _dio.post('/overtime-requests/$id/reject');
  }
}
