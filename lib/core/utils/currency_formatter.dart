import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _formatterCompact = NumberFormat.compactCurrency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _formatterNoSymbol = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  /// Format: Rp 10.000
  static String format(int amount) {
    return _formatter.format(amount);
  }

  /// Format compact: Rp 10rb, Rp 1jt
  static String formatCompact(int amount) {
    return _formatterCompact.format(amount);
  }

  /// Format without symbol: 10.000
  static String formatNoSymbol(int amount) {
    return _formatterNoSymbol.format(amount).trim();
  }

  /// Parse currency string to int
  /// Input: "Rp 10.000" or "10.000" or "10000"
  /// Output: 10000
  static int parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  /// Format with sign: +Rp 10.000 or -Rp 10.000
  static String formatWithSign(int amount) {
    if (amount >= 0) {
      return '+${format(amount)}';
    }
    return '-${format(amount.abs())}';
  }

  /// Format for input field (no symbol, with thousand separator)
  static String formatForInput(String text) {
    final number = parse(text);
    if (number == 0) return '';
    return formatNoSymbol(number);
  }
}
