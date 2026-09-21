import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/leave_api.dart';

final leaveApiProvider = Provider<LeaveApi>((ref) => LeaveApi(ref.watch(dioProvider)));

final myLeaveRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(leaveApiProvider).getMyLeaveRequests();
});

final leaveApprovalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(leaveApiProvider).getPendingApprovals();
});

final myLeaveQuotaProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(leaveApiProvider).getMyQuota();
});

final approvalConfigsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(leaveApiProvider).getApprovalConfigs();
});
