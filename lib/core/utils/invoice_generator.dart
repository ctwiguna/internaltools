import 'package:flutter_laundry_offline_app/core/constants/app_constants.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/utils/date_formatter.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';

class InvoiceGenerator {
  /// Generate invoice number
  /// Format: PREFIX-YYMMDD-NNNN
  /// Example: LNDR-260115-0001
  static Future<String> generate() async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now();
    final dateStr = DateFormatter.formatForInvoice(today);

    // Get prefix from current outlet (not from app_settings)
    final currentOutlet = OutletService.instance.currentOutlet;
    final prefix = currentOutlet?.invoicePrefix ?? AppConstants.defaultInvoicePrefix;

    // Use transaction to prevent race condition
    return await db.transaction((txn) async {
      // Find the highest invoice number for today directly from orders table
      // This is more reliable than using settings
      final pattern = '$prefix-$dateStr-%';
      final result = await txn.rawQuery('''
        SELECT invoice_no FROM orders
        WHERE invoice_no LIKE ?
        ORDER BY invoice_no DESC
        LIMIT 1
      ''', [pattern]);

      int nextNumber = 1;
      if (result.isNotEmpty) {
        final lastInvoice = result.first['invoice_no'] as String;
        final lastSeq = extractSequence(lastInvoice);
        if (lastSeq != null) {
          nextNumber = lastSeq + 1;
        }
      }

      // Format: LNDR-260115-0001
      final paddedNumber = nextNumber.toString().padLeft(AppConstants.invoiceNumberLength, '0');
      return '$prefix-$dateStr-$paddedNumber';
    });
  }

  /// Validate invoice format
  static bool isValidInvoice(String invoice) {
    // Pattern: PREFIX-YYMMDD-NNNN
    final pattern = RegExp(r'^[A-Z]+-\d{6}-\d{4}$');
    return pattern.hasMatch(invoice);
  }

  /// Extract date from invoice
  static DateTime? extractDate(String invoice) {
    try {
      final parts = invoice.split('-');
      if (parts.length != 3) return null;

      final dateStr = parts[1];
      final year = 2000 + int.parse(dateStr.substring(0, 2));
      final month = int.parse(dateStr.substring(2, 4));
      final day = int.parse(dateStr.substring(4, 6));

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  /// Extract sequence number from invoice
  static int? extractSequence(String invoice) {
    try {
      final parts = invoice.split('-');
      if (parts.length != 3) return null;
      return int.parse(parts[2]);
    } catch (e) {
      return null;
    }
  }
}
