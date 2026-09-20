import 'package:dio/dio.dart';

class AttendanceApi {
  AttendanceApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> clockIn({
    required List<int> photoBytes,
    required String filename,
    required double latitude,
    required double longitude,
    String? note,
  }) async {
    final res = await _dio.post('/attendance/clock-in', data: _buildFormData(
      photoBytes: photoBytes,
      filename: filename,
      latitude: latitude,
      longitude: longitude,
      note: note,
    ));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> clockOut({
    required List<int> photoBytes,
    required String filename,
    required double latitude,
    required double longitude,
    String? note,
  }) async {
    final res = await _dio.post('/attendance/clock-out', data: _buildFormData(
      photoBytes: photoBytes,
      filename: filename,
      latitude: latitude,
      longitude: longitude,
      note: note,
    ));
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyAttendance() async {
    final res = await _dio.get('/attendance/me');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  FormData _buildFormData({
    required List<int> photoBytes,
    required String filename,
    required double latitude,
    required double longitude,
    String? note,
  }) {
    return FormData.fromMap({
      'photo': MultipartFile.fromBytes(photoBytes, filename: filename),
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }
}
