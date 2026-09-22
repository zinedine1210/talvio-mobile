import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/dashboard_api.dart';

final dashboardApiProvider =
    Provider<DashboardApi>((ref) => DashboardApi(ref.watch(dioProvider)));

final dashboardSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(dashboardApiProvider).getSummary();
});
