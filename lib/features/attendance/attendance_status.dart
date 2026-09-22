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
  final todayRecord = findAttendanceForDate(records, todayDate);
  if (todayRecord == null) return AttendanceAction.clockIn;
  final clockOutAt = todayRecord['clock_out_at'];
  if (clockOutAt == null || clockOutAt.toString().isEmpty) {
    return AttendanceAction.clockOut;
  }
  return AttendanceAction.done;
}

/// Finds the record in `records` whose `date` field matches `targetDate`
/// ("YYYY-MM-DD"). Backend serializes `date` as a full RFC3339 timestamp
/// (e.g. "2026-09-21T00:00:00Z"), not a bare date string — parse it instead
/// of comparing raw strings. Stays in UTC (no .toLocal()): the backend
/// already encodes this at UTC midnight to mark the Jakarta calendar day
/// (see talvio-backend's timeutil.DateOf), so converting to the device's
/// local zone could shift it to the wrong day.
Map<String, dynamic>? findAttendanceForDate(
  List<Map<String, dynamic>> records,
  String targetDate,
) {
  for (final r in records) {
    final parsed = DateTime.tryParse(r['date']?.toString() ?? '');
    if (parsed == null) continue;
    final recordDate =
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    if (recordDate == targetDate) return r;
  }
  return null;
}

/// Today's date as `YYYY-MM-DD`. Uses the device's local clock — MVP
/// assumes every company is in WIB (see SPEC.md), same simplification the
/// backend makes, so this deliberately doesn't force a UTC+7 conversion.
String todayDateString([DateTime? now]) {
  final n = now ?? DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
