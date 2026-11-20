import 'package:dio/dio.dart';

class AnnouncementApi {
  AnnouncementApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final res = await _dio.get('/announcements');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// HR-only on the backend (route-gated).
  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String body,
    required String target,
    int? departmentId,
  }) async {
    final res = await _dio.post('/announcements', data: {
      'title': title,
      'body': body,
      'target': target,
      if (departmentId != null) 'department_id': departmentId,
    });
    return res.data as Map<String, dynamic>;
  }
}
