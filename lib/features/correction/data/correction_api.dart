import 'package:dio/dio.dart';

class CorrectionApi {
  CorrectionApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> createCorrection({
    required int attendanceId,
    required String field,
    required String time,
    required String reason,
  }) async {
    final res = await _dio.post('/attendance/$attendanceId/corrections', data: {
      'field': field,
      'time': time,
      'reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }

  /// HR-only on the backend (route-gated) — corrections are always
  /// approved by HR, never routed through the approval resolver.
  Future<List<Map<String, dynamic>>> getPendingCorrections() async {
    final res = await _dio.get('/corrections');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> approve(int id) async {
    await _dio.post('/corrections/$id/approve');
  }

  Future<void> reject(int id) async {
    await _dio.post('/corrections/$id/reject');
  }
}
