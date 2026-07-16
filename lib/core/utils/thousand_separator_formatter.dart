import 'package:flutter/services.dart';

/// Input formatter yang menambahkan separator ribuan (titik)
/// Contoh: 1000000 -> 1.000.000
class ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Format with thousand separators
    final formatted = _formatWithThousands(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithThousands(String value) {
    final result = StringBuffer();
    final length = value.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        result.write('.');
      }
      result.write(value[i]);
    }

    return result.toString();
  }

  /// Parse formatted string to integer
  /// Contoh: "1.000.000" -> 1000000
  static int parseToInt(String formattedValue) {
    if (formattedValue.isEmpty) return 0;
    final digitsOnly = formattedValue.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digitsOnly) ?? 0;
  }

  /// Format integer to string with thousand separators
  /// Contoh: 1000000 -> "1.000.000"
  static String format(int value) {
    final result = StringBuffer();
    final str = value.toString();
    final length = str.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        result.write('.');
      }
      result.write(str[i]);
    }

    return result.toString();
  }
}
