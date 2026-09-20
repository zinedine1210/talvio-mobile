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
}
