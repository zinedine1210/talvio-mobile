import 'package:flutter_test/flutter_test.dart';
import 'package:talvio_mobile/core/geo.dart';
import 'package:talvio_mobile/features/attendance/attendance_status.dart';

void main() {
  group('determineAttendanceAction', () {
    test('no record today -> clockIn', () {
      final action = determineAttendanceAction([], '2026-01-15');
      expect(action, AttendanceAction.clockIn);
    });

    test('record today with no clock_out_at -> clockOut', () {
      final action = determineAttendanceAction([
        {'date': '2026-01-15', 'clock_in_at': '2026-01-15T08:00:00Z', 'clock_out_at': null},
      ], '2026-01-15');
      expect(action, AttendanceAction.clockOut);
    });

    test('record today with clock_out_at -> done', () {
      final action = determineAttendanceAction([
        {
          'date': '2026-01-15',
          'clock_in_at': '2026-01-15T08:00:00Z',
          'clock_out_at': '2026-01-15T17:00:00Z',
        },
      ], '2026-01-15');
      expect(action, AttendanceAction.done);
    });

    test('only a record from a previous day -> clockIn', () {
      final action = determineAttendanceAction([
        {
          'date': '2026-01-14',
          'clock_in_at': '2026-01-14T08:00:00Z',
          'clock_out_at': '2026-01-14T17:00:00Z',
        },
      ], '2026-01-15');
      expect(action, AttendanceAction.clockIn);
    });
  });

  test('todayDateString formats with zero-padding', () {
    expect(todayDateString(DateTime(2026, 1, 5)), '2026-01-05');
  });

  group('distanceInMeters', () {
    test('same point is zero distance', () {
      expect(distanceInMeters(-6.2, 106.8, -6.2, 106.8), closeTo(0, 0.001));
    });

    test('known distance is approximately correct', () {
      // Roughly 1 degree of latitude ~= 111km.
      final d = distanceInMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 200));
    });
  });
}
