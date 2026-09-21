import 'package:flutter_test/flutter_test.dart';
import 'package:talvio_mobile/features/leave/leave_duration.dart';

void main() {
  test('same day counts as 1 day', () {
    expect(leaveDurationDays(DateTime(2026, 1, 10), DateTime(2026, 1, 10)), 1);
  });

  test('inclusive range counts both ends', () {
    expect(leaveDurationDays(DateTime(2026, 1, 10), DateTime(2026, 1, 12)), 3);
  });

  test('spans a month boundary correctly', () {
    expect(leaveDurationDays(DateTime(2026, 1, 30), DateTime(2026, 2, 2)), 4);
  });
}
