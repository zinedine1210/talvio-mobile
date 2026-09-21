import 'package:dio/dio.dart';

class LeaveApi {
  LeaveApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> createLeaveRequest({
    required String type,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    final res = await _dio.post('/leave-requests', data: {
      'type': type,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyLeaveRequests() async {
    final res = await _dio.get('/leave-requests/me');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Requests awaiting action from whoever is logged in — could be an HR
  /// admin or an ordinary employee acting as someone's supervisor/delegate,
  /// per the approval resolver in SPEC.md.
  Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    final res = await _dio.get('/leave-requests');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> approve(int id) async {
    await _dio.post('/leave-requests/$id/approve');
  }

  Future<void> reject(int id) async {
    await _dio.post('/leave-requests/$id/reject');
  }

  Future<Map<String, dynamic>> getMyQuota() async {
    final res = await _dio.get('/leave-quotas/me');
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getApprovalConfigs() async {
    final res = await _dio.get('/company/approval-configs');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateApprovalConfigs(List<Map<String, dynamic>> configs) async {
    await _dio.put('/company/approval-configs', data: configs);
  }
}
