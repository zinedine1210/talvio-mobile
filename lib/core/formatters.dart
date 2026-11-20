import 'package:flutter/services.dart';

const _bulanIndonesia = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String formatDateLong(DateTime date) =>
    '${date.day} ${_bulanIndonesia[date.month - 1]} ${date.year}';

/// "November 2026" — for period labels (payslip, attendance report) where
/// showing a specific day would be misleading since the value spans a
/// whole month.
String formatMonthYear(DateTime date) => '${_bulanIndonesia[date.month - 1]} ${date.year}';

/// Local wall-clock date + time, e.g. "21 September 2026, 08:15" — for
/// fields with a real time component (clock_in_at, created_at, and
/// similar), as opposed to [formatDateLong] for date-only fields
/// (start_date, join_date).
String formatDateTimeLong(DateTime date) {
  final local = date.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${formatDateLong(local)}, $hh:$mm';
}

/// Parses an API date string (e.g. a JSON field value) and formats it, or
/// returns the raw value unchanged if it isn't parseable — never throws.
String formatDateLongFromString(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : formatDateLong(parsed);
}

String _withThousandsSeparator(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String formatRupiah(int amount) => 'Rp ${_withThousandsSeparator(amount.toString())}';

/// "2 hari lalu" style relative time, matching figma's announcement cards.
/// Falls back to the absolute date past ~a month since "30 hari lalu" reads
/// worse than just the date at that point.
String formatRelativeTime(DateTime date) {
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
  return formatDateLong(date.toLocal());
}

/// Formats a plain-integer TextField as Indonesian Rupiah while typing
/// (e.g. "5000000" -> "5.000.000"). Pair with [parseRupiahInput] to get the
/// raw integer back before sending it to the API.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = _withThousandsSeparator(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

int parseRupiahInput(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
