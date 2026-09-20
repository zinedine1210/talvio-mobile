import 'package:flutter/services.dart';

const _bulanIndonesia = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String formatDateLong(DateTime date) =>
    '${date.day} ${_bulanIndonesia[date.month - 1]} ${date.year}';

String _withThousandsSeparator(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String formatRupiah(int amount) => 'Rp ${_withThousandsSeparator(amount.toString())}';

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
