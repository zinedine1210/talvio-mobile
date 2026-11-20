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
    double? faceMatchScore,
    String? faceMatchStatus,
  }) async {
    final res = await _dio.post('/attendance/clock-in', data: _buildFormData(
      photoBytes: photoBytes,
      filename: filename,
      latitude: latitude,
      longitude: longitude,
      note: note,
      faceMatchScore: faceMatchScore,
      faceMatchStatus: faceMatchStatus,
    ));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> clockOut({
    required List<int> photoBytes,
    required String filename,
    required double latitude,
    required double longitude,
    String? note,
    double? faceMatchScore,
    String? faceMatchStatus,
  }) async {
    final res = await _dio.post('/attendance/clock-out', data: _buildFormData(
      photoBytes: photoBytes,
      filename: filename,
      latitude: latitude,
      longitude: longitude,
      note: note,
      faceMatchScore: faceMatchScore,
      faceMatchStatus: faceMatchStatus,
    ));
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyAttendance() async {
    final res = await _dio.get('/attendance/me');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPendingReview() async {
    final res = await _dio.get('/attendance/pending-review');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> review(int id, {required String status, String? note}) async {
    await _dio.post('/attendance/$id/review', data: {
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  FormData _buildFormData({
    required List<int> photoBytes,
    required String filename,
    required double latitude,
    required double longitude,
    String? note,
    double? faceMatchScore,
    String? faceMatchStatus,
  }) {
    return FormData.fromMap({
      'photo': MultipartFile.fromBytes(photoBytes, filename: filename),
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      if (note != null && note.isNotEmpty) 'note': note,
      if (faceMatchScore != null) 'face_match_score': faceMatchScore.toString(),
      if (faceMatchStatus != null) 'face_match_status': faceMatchStatus,
    });
  }
}
