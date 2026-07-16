class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Zenn Laundry';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'by Chandra Ganteng';

  // Database
  static const String databaseName = 'laundry_v5.db';
  static const int databaseVersion = 6; // v6: attendance, shifts, cash_expenses

  // Settings Keys - Outlet
  static const String keyCurrentOutletId = 'current_outlet_id';

  // Invoice
  static const String defaultInvoicePrefix = 'LNDR';
  static const int invoiceNumberLength = 4;

  // Default Values
  static const int defaultServiceDuration = 3; // days
  static const String defaultPaymentMethod = 'cash';

  // Pagination
  static const int defaultPageSize = 20;
  static const int recentOrdersLimit = 5;

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String dateTimeFormat = 'dd MMM yyyy HH:mm';
  static const String dateFormatShort = 'dd/MM/yy';
  static const String timeFormat = 'HH:mm';
  static const String invoiceDateFormat = 'yyMMdd';

  // Printer
  static const int printerPaperWidth = 58; // mm
  static const int printerCharPerLine = 32;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 20;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;

  // Default Admin Credentials
  static const String defaultOwnerUsername = 'ctwiguna';
  static const String defaultOwnerPassword = 'chandraganteng';
  static const String defaultOwnerName = 'Chandra';

  // Settings Keys
  static const String keyLaundryName = 'laundry_name';
  static const String keyLaundryAddress = 'laundry_address';
  static const String keyLaundryPhone = 'laundry_phone';
  static const String keyInvoicePrefix = 'invoice_prefix';
  static const String keyPrinterAddress = 'printer_address';
  static const String keyLastInvoiceDate = 'last_invoice_date';
  static const String keyLastInvoiceNumber = 'last_invoice_number';

  // Default Laundry Info
  static const String defaultLaundryName = 'Zenn Laundry';
  static const String defaultLaundryAddress = 'Jl. Kedungmundu Raya No.511, Kota Semarang';
  static const String defaultLaundryPhone = '6285158771256';
}
