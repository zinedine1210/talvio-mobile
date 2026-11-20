import 'package:flutter_test/flutter_test.dart';
import 'package:talvio_mobile/core/formatters.dart';

void main() {
  test('formatRupiah inserts thousands separators', () {
    expect(formatRupiah(5000000), 'Rp 5.000.000');
    expect(formatRupiah(1000), 'Rp 1.000');
    expect(formatRupiah(999), 'Rp 999');
  });

  test('formatDateLong uses Indonesian long format', () {
    expect(formatDateLong(DateTime(2024, 1, 15)), '15 Januari 2024');
  });

  test('parseRupiahInput strips formatting back to a plain integer', () {
    expect(parseRupiahInput('Rp 5.000.000'), 5000000);
    expect(parseRupiahInput(''), 0);
  });

  test('formatDateTimeLong appends local hour:minute', () {
    expect(formatDateTimeLong(DateTime(2024, 1, 15, 8, 5)), '15 Januari 2024, 08:05');
  });

  test('formatDateLongFromString parses an API date string', () {
    expect(formatDateLongFromString('2026-09-21'), '21 September 2026');
    expect(formatDateLongFromString('2026-09-21T08:15:00Z'), '21 September 2026');
  });

  test('formatDateLongFromString falls back gracefully', () {
    expect(formatDateLongFromString(null), '-');
    expect(formatDateLongFromString(''), '-');
    expect(formatDateLongFromString('not-a-date'), 'not-a-date');
  });
}
