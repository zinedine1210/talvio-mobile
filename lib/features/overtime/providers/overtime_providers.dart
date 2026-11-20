import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/overtime_api.dart';

final overtimeApiProvider =
    Provider<OvertimeApi>((ref) => OvertimeApi(ref.watch(dioProvider)));

final myOvertimeRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(overtimeApiProvider).getMyOvertimeRequests();
});

final overtimeApprovalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(overtimeApiProvider).getPendingApprovals();
});
