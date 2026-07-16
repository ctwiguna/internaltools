import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class DateFormatter {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (!_initialized) {
      await initializeDateFormatting('id_ID', null);
      _initialized = true;
    }
  }

  /// Format: 15 Jan 2026
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  /// Format: 15 Jan 2026 14:30
  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(date);
  }

  /// Format: 15/01/26
  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  /// Format: 14:30
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Format: 260115 (for invoice)
  static String formatForInvoice(DateTime date) {
    return DateFormat('yyMMdd').format(date);
  }

  /// Format: 2026-01-15 (ISO date only)
  static String formatIsoDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format: 20260115 (compact for file names)
  static String formatDateCompact(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  /// Format relative: Hari ini, Kemarin, 2 hari lalu, etc
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateOnly).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff == -1) return 'Besok';
    if (diff > 0 && diff < 7) return '$diff hari lalu';
    if (diff < 0 && diff > -7) return '${-diff} hari lagi';
    return formatDate(date);
  }

  /// Check if date is overdue
  static bool isOverdue(DateTime? dueDate) {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.isAfter(due);
  }

  /// Get days until due date
  static int daysUntilDue(DateTime? dueDate) {
    if (dueDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  /// Format due date with status
  static String formatDueDate(DateTime? dueDate) {
    if (dueDate == null) return '-';
    final days = daysUntilDue(dueDate);
    if (days < 0) return 'Terlambat ${-days} hari';
    if (days == 0) return 'Hari ini';
    if (days == 1) return 'Besok';
    return '$days hari lagi';
  }

  /// Parse date string (ISO format)
  static DateTime? parse(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Get start of month
  static DateTime startOfMonth(int year, int month) {
    return DateTime(year, month, 1);
  }

  /// Get end of month
  static DateTime endOfMonth(int year, int month) {
    return DateTime(year, month + 1, 0, 23, 59, 59, 999);
  }

  /// Get start of week (Monday)
  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  /// Get end of week (Sunday)
  static DateTime endOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(
        date.year, date.month, date.day + (7 - weekday), 23, 59, 59, 999);
  }
}
