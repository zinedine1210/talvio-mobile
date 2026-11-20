import 'package:dio/dio.dart';

class EmployeeApi {
  EmployeeApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> uploadPhoto(int id, List<int> photoBytes, String filename) async {
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(photoBytes, filename: filename),
    });
    final res = await _dio.post('/employees/$id/photo', data: formData);
    return res.data as Map<String, dynamic>;
  }

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

  Future<Map<String, dynamic>> updateMe({String? name, String? phone, String? address}) async {
    final res = await _dio.patch('/employees/me', data: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadMyPhoto(List<int> photoBytes, String filename) async {
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(photoBytes, filename: filename),
    });
    final res = await _dio.post('/employees/me/photo', data: formData);
    return res.data as Map<String, dynamic>;
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _dio.patch('/employees/me/password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> updateNotificationPrefs({required bool notifyPush, required bool notifyEmail}) async {
    await _dio.patch('/employees/me/notifications', data: {
      'notify_push': notifyPush,
      'notify_email': notifyEmail,
    });
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

  Future<Map<String, dynamic>> updateDepartment(int id, String name) async {
    final res = await _dio.put('/departments/$id', data: {'name': name});
    return res.data as Map<String, dynamic>;
  }

  Future<void> deactivateDepartment(int id) async {
    await _dio.delete('/departments/$id');
  }

  Future<List<Map<String, dynamic>>> listLocations() async {
    final res = await _dio.get('/company/locations');
    return (res.data as List).cast<Map<String, dynamic>>();
  }
}
