import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/attendance_api.dart';

final attendanceApiProvider =
    Provider<AttendanceApi>((ref) => AttendanceApi(ref.watch(dioProvider)));

final myAttendanceProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(attendanceApiProvider).getMyAttendance();
});
