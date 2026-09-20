enum AttendanceAction { clockIn, clockOut, done }

/// Decides which button to show based on today's attendance records.
/// Pure function — no I/O, easy to test without a device.
///
/// `todayDate` must be `YYYY-MM-DD` (same format the backend uses for the
/// `date` field, see SPEC.md "Konvensi Format").
AttendanceAction determineAttendanceAction(
  List<Map<String, dynamic>> records,
  String todayDate,
) {
  Map<String, dynamic>? todayRecord;
  for (final r in records) {
    if (r['date']?.toString() == todayDate) {
      todayRecord = r;
      break;
    }
  }
  if (todayRecord == null) return AttendanceAction.clockIn;
  final clockOutAt = todayRecord['clock_out_at'];
  if (clockOutAt == null || clockOutAt.toString().isEmpty) {
    return AttendanceAction.clockOut;
  }
  return AttendanceAction.done;
}

/// Today's date as `YYYY-MM-DD`. Uses the device's local clock — MVP
/// assumes every company is in WIB (see SPEC.md), same simplification the
/// backend makes, so this deliberately doesn't force a UTC+7 conversion.
String todayDateString([DateTime? now]) {
  final n = now ?? DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
