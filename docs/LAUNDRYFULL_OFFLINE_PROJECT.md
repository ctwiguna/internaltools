# LaundryFull Offline - UMKM Indonesia

> **Target**: Aplikasi laundry offline untuk UMKM Indonesia  
> **Tech Stack**: Flutter + SQLite + Cubit  
> **Timeline**: 6-7 hari development  
> **Demo**: Webinar/Sharing Session

---

## 🎯 Overview

Aplikasi kasir laundry offline yang simple, works, dan actually dipakai oleh owner laundry UMKM. Fokus ke fitur yang **benar-benar dibutuhkan**, bukan fitur yang "keren tapi ga kepake".

### Problem yang Dipecahkan
- ❌ Nota manual rawan hilang
- ❌ Susah tracking status cucian (lagi dicuci, sudah selesai, sudah diambil)
- ❌ Hitung omzet manual ribet
- ❌ Ga ada histori transaksi
- ❌ Printer thermal mahal

### Solution
- ✅ Digital order management dengan **flexible workflow**
- ✅ Auto reminder via WhatsApp
- ✅ Laporan otomatis harian/bulanan
- ✅ Histori lengkap semua transaksi
- ✅ Print via bluetooth dari HP

### Workflow Fleksibel
```
FLOW 1 (Langsung selesai):
Order (Pending) → Process → Done
└─ Cocok untuk: laundry cepat, customer langsung tunggu

FLOW 2 (Ada tahap ready):
Order (Pending) → Process → Ready → Done
└─ Cocok untuk: laundry reguler, customer ambil besok/lusa
```

---

## 📊 Database Schema (SQLite)

### ERD Concept
```
orders (1) ----< (N) order_items
orders (1) ----< (N) payments
order_items (N) >---- (1) services
```

### Table: orders
```sql
CREATE TABLE orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_no TEXT UNIQUE NOT NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  order_date TEXT NOT NULL,
  due_date TEXT,
  status TEXT NOT NULL, -- pending, process, ready, done
  total_items INTEGER DEFAULT 0,
  total_weight REAL DEFAULT 0,
  total_price INTEGER NOT NULL,
  paid INTEGER DEFAULT 0,
  notes TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Index untuk performa
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_invoice ON orders(invoice_no);

-- INVOICE FORMAT: LNDR-YYMMDD-NNNN
-- Example:
--   LNDR-260115-0001  (15 Jan 2026, order pertama)
--   LNDR-260115-0002  (15 Jan 2026, order kedua)
--   LNDR-260115-0003  (15 Jan 2026, order ketiga)
--   LNDR-260116-0001  (16 Jan 2026, RESET ke 0001)
--   LNDR-260116-0002  (16 Jan 2026, order kedua)
-- 
-- LNDR = Laundry prefix (customizable)
-- YYMMDD = Year-Month-Day (2 digit year)
-- NNNN = Sequential number (4 digit, reset daily)

-- STATUS FLOW (Flexible):
-- Flow 1: pending → process → done (langsung selesai)
-- Flow 2: pending → process → ready → done (ada tahap siap diambil)
-- 
-- pending = order baru masuk
-- process = sedang dikerjakan
-- ready = sudah selesai, siap diambil (OPTIONAL)
-- done = sudah diambil customer / selesai
```

### Table: order_items
```sql
CREATE TABLE order_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  service_type TEXT NOT NULL, -- cuci_kering, cuci_setrika, setrika_saja
  quantity REAL NOT NULL, -- berat dalam kg atau jumlah pcs
  unit TEXT NOT NULL, -- kg atau pcs
  price_per_unit INTEGER NOT NULL,
  subtotal INTEGER NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
```

### Table: services
```sql
CREATE TABLE services (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  unit TEXT NOT NULL, -- kg atau pcs
  price INTEGER NOT NULL,
  duration_days INTEGER DEFAULT 3,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Data master default
INSERT INTO services (name, unit, price, duration_days) VALUES
('Cuci Kering', 'kg', 8000, 3),
('Cuci Setrika', 'kg', 10000, 3),
('Setrika Saja', 'kg', 5000, 2),
('Cuci Bed Cover', 'pcs', 25000, 4),
('Cuci Karpet', 'pcs', 35000, 5),
('Cuci Boneka', 'pcs', 15000, 3);
```

### Table: payments
```sql
CREATE TABLE payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  payment_date TEXT NOT NULL,
  payment_method TEXT NOT NULL, -- cash, transfer, qris
  notes TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_date ON payments(payment_date);
```

### Table: app_settings
```sql
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Default settings
INSERT INTO app_settings (key, value) VALUES
('laundry_name', 'Laundry Bersih Jaya'),
('laundry_address', 'Jl. Melati No. 45'),
('laundry_phone', '0812-3456-7890'),
('invoice_prefix', 'LNDR'),
('printer_address', ''),
('last_invoice_date', ''),
('last_invoice_number', '0');
```

---

## 📁 Folder Structure

```
laundryfull_offline/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   └── colors.dart
│   │   ├── utils/
│   │   │   ├── date_formatter.dart
│   │   │   ├── currency_formatter.dart
│   │   │   └── invoice_generator.dart
│   │   └── exceptions/
│   │       └── database_exception.dart
│   ├── data/
│   │   ├── database/
│   │   │   └── database_helper.dart
│   │   ├── models/
│   │   │   ├── order.dart
│   │   │   ├── order_item.dart
│   │   │   ├── service.dart
│   │   │   ├── payment.dart
│   │   │   └── app_setting.dart
│   │   └── repositories/
│   │       ├── order_repository.dart
│   │       ├── service_repository.dart
│   │       ├── payment_repository.dart
│   │       └── settings_repository.dart
│   ├── logic/
│   │   └── cubits/
│   │       ├── order/
│   │       │   ├── order_cubit.dart
│   │       │   └── order_state.dart
│   │       ├── service/
│   │       │   ├── service_cubit.dart
│   │       │   └── service_state.dart
│   │       ├── printer/
│   │       │   ├── printer_cubit.dart
│   │       │   └── printer_state.dart
│   │       └── report/
│   │           ├── report_cubit.dart
│   │           └── report_state.dart
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── dashboard/
│   │   │   │   └── dashboard_screen.dart
│   │   │   ├── orders/
│   │   │   │   ├── order_list_screen.dart
│   │   │   │   ├── order_form_screen.dart
│   │   │   │   └── order_detail_screen.dart
│   │   │   ├── services/
│   │   │   │   ├── service_list_screen.dart
│   │   │   │   └── service_form_screen.dart
│   │   │   ├── reports/
│   │   │   │   └── report_screen.dart
│   │   │   └── settings/
│   │   │       ├── settings_screen.dart
│   │   │       └── printer_settings_screen.dart
│   │   └── widgets/
│   │       ├── order_card.dart
│   │       ├── service_card.dart
│   │       ├── status_badge.dart
│   │       ├── custom_button.dart
│   │       └── loading_overlay.dart
│   └── main.dart
├── pubspec.yaml
└── README.md
```

---

## 📦 Dependencies (pubspec.yaml)

```yaml
name: laundryfull_offline
description: Aplikasi Kasir Laundry Offline untuk UMKM Indonesia
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  
  # Database
  sqflite: ^2.3.0
  path: ^1.8.3
  
  # Utilities
  intl: ^0.18.1  # Format tanggal & currency
  uuid: ^4.1.0   # Generate unique ID
  
  # Printer Bluetooth
  blue_thermal_printer: ^1.2.2
  esc_pos_utils: ^1.1.0
  image: ^4.1.3  # For logo printing
  
  # Share & Permissions
  share_plus: ^7.2.1
  permission_handler: ^11.0.1
  path_provider: ^2.1.1
  
  # UI
  google_fonts: ^6.1.0
  fl_chart: ^0.65.0  # Simple charts untuk laporan

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/icons/
```

---

## 🚀 Development Todolist

### **FASE 1: Setup Project & Database** ⏱️ Hari 1

#### Setup
- [ ] Create Flutter project
- [ ] Setup dependencies di `pubspec.yaml`
- [ ] Create folder structure sesuai arsitektur
- [ ] Setup constants (colors, text styles, app config)

#### Database Setup
- [ ] **database_helper.dart**
  - [ ] Create DatabaseHelper singleton class
  - [ ] Implement `initDatabase()` method
  - [ ] Create all tables (orders, order_items, services, payments, app_settings)
  - [ ] Add indexes
  - [ ] Implement migration handler
  - [ ] Seed default data (services & settings)

```dart
// Snippet: database_helper.dart structure
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('laundryfull.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Create tables here...
  }
}
```

#### Models
- [ ] **order.dart** - Model + toMap/fromMap
- [ ] **order_item.dart** - Model + toMap/fromMap
- [ ] **service.dart** - Model + toMap/fromMap
- [ ] **payment.dart** - Model + toMap/fromMap
- [ ] **app_setting.dart** - Model + toMap/fromMap

```dart
// Snippet: order.dart structure
class Order extends Equatable {
  final int? id;
  final String invoiceNo;
  final String customerName;
  final String? customerPhone;
  final DateTime orderDate;
  final DateTime? dueDate;
  final OrderStatus status;
  final int totalItems;
  final double totalWeight;
  final int totalPrice;
  final int paid;
  final String? notes;

  const Order({...});

  Map<String, dynamic> toMap() {...}
  factory Order.fromMap(Map<String, dynamic> map) {...}
  
  Order copyWith({...}) {...}
  
  // Get available next status transitions
  List<OrderStatus> getNextStatusOptions() {
    switch (status) {
      case OrderStatus.pending:
        return [OrderStatus.process];
      case OrderStatus.process:
        // Flexible: bisa langsung Done atau lewat Ready dulu
        return [OrderStatus.ready, OrderStatus.done];
      case OrderStatus.ready:
        return [OrderStatus.done];
      case OrderStatus.done:
        return []; // Final state
    }
  }
  
  @override
  List<Object?> get props => [...];
}

enum OrderStatus { 
  pending,  // Order baru masuk
  process,  // Sedang dikerjakan
  ready,    // Sudah selesai, siap diambil (OPTIONAL)
  done      // Sudah diambil / selesai
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.process:
        return 'Process';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.done:
        return 'Done';
    }
  }
  
  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Order baru masuk';
      case OrderStatus.process:
        return 'Sedang dikerjakan';
      case OrderStatus.ready:
        return 'Selesai, siap diambil';
      case OrderStatus.done:
        return 'Sudah diambil';
    }
  }
}
```

#### Testing Database
- [ ] Create dummy data generator
- [ ] Test insert/read/update/delete operations
- [ ] Verify foreign key constraints
- [ ] Test transaction rollback

---

### **FASE 2: Service Management** ⏱️ Hari 1-2

#### Repository
- [ ] **service_repository.dart**
  - [ ] `getAllServices()` - Get all active services
  - [ ] `getServiceById(int id)` - Get specific service
  - [ ] `createService(Service service)` - Add new service
  - [ ] `updateService(Service service)` - Update existing
  - [ ] `deleteService(int id)` - Soft delete (set is_active = 0)

#### Cubit
- [ ] **service_cubit.dart**
  - [ ] States: ServiceInitial, ServiceLoading, ServiceLoaded, ServiceError
  - [ ] `loadServices()` - Load all services
  - [ ] `addService(Service service)` - Validate & add
  - [ ] `updateService(Service service)` - Update
  - [ ] `deleteService(int id)` - Delete with confirmation

#### UI
- [ ] **service_list_screen.dart**
  - [ ] AppBar dengan title + add button
  - [ ] ListView.builder dengan ServiceCard
  - [ ] Empty state (belum ada paket)
  - [ ] Pull to refresh
  - [ ] Search/filter (optional)

- [ ] **service_form_screen.dart**
  - [ ] Form fields: nama, unit (dropdown), harga, durasi
  - [ ] Validation: semua field required, harga > 0
  - [ ] Save button
  - [ ] Loading state saat save

- [ ] **service_card.dart** (widget)
  - [ ] Display: nama, harga, durasi
  - [ ] Actions: edit, delete
  - [ ] Swipe to delete (optional)

---

### **FASE 3: Order Management** ⏱️ Hari 2-3

#### Repository
- [ ] **order_repository.dart**
  - [ ] `getAllOrders({OrderStatus? status})` - Filter by status
  - [ ] `getOrderById(int id)` - With items & payments (JOIN)
  - [ ] `createOrder(Order order, List<OrderItem> items)` - Transaction
  - [ ] `updateOrderStatus(int id, OrderStatus status)` - Update status
  - [ ] `searchOrders(String query)` - By customer name/phone/invoice
  - [ ] `getOrdersByDateRange(DateTime start, DateTime end)` - For reports

#### Repository
- [ ] **payment_repository.dart**
  - [ ] `getPaymentsByOrderId(int orderId)` - Get all payments
  - [ ] `addPayment(Payment payment)` - Add payment & update order.paid
  - [ ] `getTotalPaidAmount(int orderId)` - Sum payments

#### Cubit
- [ ] **order_cubit.dart**
  - [ ] States: OrderInitial, OrderLoading, OrderLoaded, OrderError, OrderCreated
  - [ ] `loadOrders({OrderStatus? status})` - Load & filter
  - [ ] `loadOrderDetail(int id)` - Load with items & payments
  - [ ] `createOrder(...)` - Validate, generate invoice, save
  - [ ] `updateStatus(int id, OrderStatus newStatus)` - Update
  - [ ] `addPayment(Payment payment)` - Add payment
  - [ ] `searchOrders(String query)` - Search

```dart
// Snippet: Generate invoice number
Future<String> _generateInvoiceNumber() async {
  final today = DateTime.now();
  final dateStr = DateFormat('yyMMdd').format(today); // Format: YYMMDD
  final todayStr = DateFormat('yyyy-MM-dd').format(today);
  final prefix = await settingsRepo.getSetting('invoice_prefix') ?? 'LNDR';
  
  // Get last invoice date & number
  final lastDate = await settingsRepo.getSetting('last_invoice_date') ?? '';
  final lastNumber = int.parse(await settingsRepo.getSetting('last_invoice_number') ?? '0');
  
  int nextNumber;
  if (lastDate == todayStr) {
    // Same day, increment
    nextNumber = lastNumber + 1;
  } else {
    // New day, reset to 1
    nextNumber = 1;
  }
  
  // Update settings
  await settingsRepo.setSetting('last_invoice_date', todayStr);
  await settingsRepo.setSetting('last_invoice_number', nextNumber.toString());
  
  return '$prefix-$dateStr-${nextNumber.toString().padLeft(4, '0')}';
  // Example: LNDR-260115-0001, LNDR-260115-0002, ...
  // Next day: LNDR-260116-0001 (reset)
}
```

#### UI
- [ ] **dashboard_screen.dart**
  - [ ] Summary cards: Total pending, Process, Ready, Done (hari ini)
  - [ ] Quick stats: Total omzet hari ini, Total order bulan ini
  - [ ] Quick actions: Tambah order, Lihat laporan
  - [ ] Recent orders (5 terakhir)

- [ ] **order_list_screen.dart**
  - [ ] Tabs/Filter by status (Semua, Pending, Process, Ready, Done)
  - [ ] ListView dengan OrderCard
  - [ ] Search bar (by nama/HP/invoice)
  - [ ] FAB: Tambah order baru
  - [ ] Pull to refresh

- [ ] **order_form_screen.dart** (Paling kompleks!)
  - [ ] Customer info section:
    - [ ] TextField: Nama customer (required)
    - [ ] TextField: No HP (optional, format validation)
  - [ ] Service items section:
    - [ ] Dropdown: Pilih service
    - [ ] TextField: Quantity (kg/pcs)
    - [ ] Display: Price per unit, Subtotal
    - [ ] Button: + Tambah item lagi
    - [ ] List selected items (editable, deletable)
  - [ ] Summary section:
    - [ ] Total items
    - [ ] Total berat/pcs
    - [ ] **TOTAL HARGA** (bold, besar)
  - [ ] Additional info:
    - [ ] DatePicker: Tanggal ambil (default: today + duration)
    - [ ] TextField: Catatan (optional)
  - [ ] DP/Bayar section:
    - [ ] TextField: Jumlah bayar (default: 0)
    - [ ] Dropdown: Metode bayar (Cash, Transfer, QRIS)
  - [ ] Button: Simpan & Print
  - [ ] Validation: min 1 item, nama tidak boleh kosong

- [ ] **order_detail_screen.dart**
  - [ ] Header: Invoice number, Status badge, Date
  - [ ] Customer info
  - [ ] Items list (read-only)
  - [ ] Payment history
  - [ ] Total & remaining payment
  - [ ] Actions:
    - [ ] **Update status button** (show dialog/bottom sheet)
      - [ ] Pending → only "Mulai Proses"
      - [ ] Process → "Selesai (Ready)" OR "Langsung Selesai (Done)"
      - [ ] Ready → only "Sudah Diambil (Done)"
      - [ ] Done → no action (final)
    - [ ] Add payment button
    - [ ] Print receipt
    - [ ] Share to WhatsApp
  - [ ] Notes display

```dart
// Snippet: Status Update Dialog
void _showStatusUpdateDialog(Order order) {
  final nextOptions = order.getNextStatusOptions();
  
  if (nextOptions.isEmpty) {
    // Already done
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order sudah selesai'))
    );
    return;
  }
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Update Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Status sekarang: ${order.status.displayName}'),
          SizedBox(height: 16),
          ...nextOptions.map((status) => ListTile(
            title: Text(status.displayName),
            subtitle: Text(status.description),
            onTap: () {
              context.read<OrderCubit>().updateStatus(order.id!, status);
              Navigator.pop(context);
            },
          )),
        ],
      ),
    ),
  );
}
```

- [ ] **order_card.dart** (widget)
  - [ ] Display: Invoice, Customer name, Status badge
  - [ ] Display: Total harga, DP/Lunas
  - [ ] Display: Due date (with overdue warning)
  - [ ] onTap: Navigate to detail

- [ ] **status_badge.dart** (widget)
  - [ ] Color coded: Pending (orange), Process (blue), Ready (green), Done (grey)
  - [ ] Icon + text

---

### **FASE 4: Printer Bluetooth** ⏱️ Hari 3-4

#### Cubit
- [ ] **printer_cubit.dart**
  - [ ] States: PrinterDisconnected, PrinterConnecting, PrinterConnected, PrinterError
  - [ ] `scanDevices()` - Scan bluetooth devices
  - [ ] `connectDevice(BluetoothDevice device)` - Connect
  - [ ] `disconnectDevice()` - Disconnect
  - [ ] `printReceipt(Order order)` - Print formatted receipt
  - [ ] `testPrint()` - Print test page

#### Printer Service
- [ ] **printer_service.dart** (Helper)
  - [ ] `generateReceiptBytes(Order order)` - Format ESC/POS
  - [ ] Handle printer errors (not connected, paper jam, dll)

```dart
// Snippet: Receipt format (58mm thermal)
Future<List<int>> generateReceiptBytes(Order order) async {
  List<int> bytes = [];
  
  // Header
  bytes += generator.text(
    'LAUNDRY BERSIH JAYA',
    styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)
  );
  bytes += generator.text('Jl. Melati No. 45');
  bytes += generator.text('0812-3456-7890');
  bytes += generator.hr();
  
  // Invoice info
  bytes += generator.row([
    PosColumn(text: 'Invoice', width: 6),
    PosColumn(text: order.invoiceNo, width: 6, styles: PosStyles(align: PosAlign.right)),
  ]);
  bytes += generator.row([
    PosColumn(text: 'Tanggal', width: 6),
    PosColumn(text: formatDate(order.orderDate), width: 6, styles: PosStyles(align: PosAlign.right)),
  ]);
  bytes += generator.text('Customer: ${order.customerName}');
  if (order.customerPhone != null) {
    bytes += generator.text('HP: ${order.customerPhone}');
  }
  bytes += generator.hr();
  
  // Items
  for (var item in order.items) {
    bytes += generator.text('${item.serviceName} (${item.quantity} ${item.unit})');
    bytes += generator.row([
      PosColumn(text: '  ${formatCurrency(item.pricePerUnit)} x ${item.quantity}', width: 8),
      PosColumn(text: formatCurrency(item.subtotal), width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
  }
  
  bytes += generator.hr();
  
  // Total
  bytes += generator.row([
    PosColumn(text: 'TOTAL', width: 6, styles: PosStyles(bold: true)),
    PosColumn(text: formatCurrency(order.totalPrice), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
  ]);
  
  if (order.paid > 0) {
    bytes += generator.row([
      PosColumn(text: 'DP', width: 6),
      PosColumn(text: formatCurrency(order.paid), width: 6, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'SISA', width: 6, styles: PosStyles(bold: true)),
      PosColumn(text: formatCurrency(order.totalPrice - order.paid), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);
  }
  
  bytes += generator.hr();
  
  // Footer
  if (order.dueDate != null) {
    bytes += generator.text('Ambil: ${formatDate(order.dueDate!)}', styles: PosStyles(align: PosAlign.center));
  }
  bytes += generator.text('Terima kasih!', styles: PosStyles(align: PosAlign.center));
  bytes += generator.hr();
  bytes += generator.feed(2);
  bytes += generator.cut();
  
  return bytes;
}
```

#### UI
- [ ] **printer_settings_screen.dart**
  - [ ] Button: Scan devices
  - [ ] List available bluetooth devices
  - [ ] Connection status indicator
  - [ ] Button: Connect/Disconnect
  - [ ] Button: Test print
  - [ ] Save printer address to settings

#### Permissions
- [ ] Request Bluetooth permissions (Android)
- [ ] Handle permission denied
- [ ] Info dialog: Cara enable bluetooth

---

### **FASE 5: Share WhatsApp** ⏱️ Hari 4

#### WhatsApp Service
- [ ] **whatsapp_service.dart**
  - [ ] `shareReceipt(Order order)` - Generate text & send
  - [ ] Format nomor HP (remove leading 0, add 62)
  - [ ] Deep link ke WA dengan nomor & text

```dart
// Snippet: Share to WhatsApp
Future<void> shareReceipt(Order order) async {
  // Format message
  final message = '''
Halo *${order.customerName}*,

Terima kasih sudah menggunakan jasa laundry kami! 

*Invoice:* ${order.invoiceNo}
*Tanggal:* ${formatDate(order.orderDate)}

*Detail Cucian:*
${order.items.map((item) => '- ${item.serviceName}: ${item.quantity} ${item.unit}').join('\n')}

*Total:* ${formatCurrency(order.totalPrice)}
*DP:* ${formatCurrency(order.paid)}
*Sisa:* ${formatCurrency(order.totalPrice - order.paid)}

📅 *Bisa diambil:* ${formatDate(order.dueDate!)}

Jika ada pertanyaan, silakan hubungi kami.

Terima kasih! 🙏
''';

  // Format phone (0856xxx -> 62856xxx)
  String phone = order.customerPhone ?? '';
  if (phone.startsWith('0')) {
    phone = '62${phone.substring(1)}';
  }
  
  // WhatsApp deep link
  final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
  
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch WhatsApp';
  }
}
```

#### Integration
- [ ] Add "Share to WA" button di order detail
- [ ] Add "Share to WA" button di order form (after create)
- [ ] Validation: customer harus punya nomor HP
- [ ] Handle error: WA not installed

---

### **FASE 6: Reports & Dashboard** ⏱️ Hari 5

#### Repository
- [ ] **report_repository.dart**
  - [ ] `getDailySummary(DateTime date)` - Omzet & count per status
  - [ ] `getMonthlySummary(int year, int month)` - Omzet per hari
  - [ ] `getPaymentSummary(DateTime start, DateTime end)` - By payment method

#### Cubit
- [ ] **report_cubit.dart**
  - [ ] States: ReportInitial, ReportLoading, ReportLoaded, ReportError
  - [ ] `loadDailyReport(DateTime date)` - Load harian
  - [ ] `loadMonthlyReport(int year, int month)` - Load bulanan
  - [ ] `exportToCSV(...)` - Export data (optional)

#### UI
- [ ] **report_screen.dart**
  - [ ] Tabs: Harian, Bulanan
  - [ ] Date picker untuk pilih periode
  
  **Tab Harian:**
  - [ ] Summary cards:
    - [ ] Total order (semua status)
    - [ ] Total pemasukan (sum payments)
    - [ ] Order pending, process, ready, done
  - [ ] Breakdown by payment method (Cash, Transfer, QRIS)
  - [ ] List orders hari itu
  
  **Tab Bulanan:**
  - [ ] Month/Year picker
  - [ ] Line chart: Omzet per hari (fl_chart)
  - [ ] Summary cards:
    - [ ] Total order bulan ini
    - [ ] Total pemasukan bulan ini
    - [ ] Rata-rata per hari
  - [ ] Top services (service paling laku)

```dart
// Snippet: Daily summary model
class DailySummary {
  final DateTime date;
  final int totalOrders;
  final int totalRevenue;
  final Map<OrderStatus, int> ordersByStatus;
  final Map<String, int> revenueByPaymentMethod;
  
  DailySummary({...});
}
```

---

### **FASE 7: Settings & Polish** ⏱️ Hari 5-6

#### Settings
- [ ] **settings_screen.dart**
  - [ ] Laundry info:
    - [ ] Edit nama laundry
    - [ ] Edit alamat
    - [ ] Edit nomor HP
  - [ ] App preferences:
    - [ ] Invoice prefix (default: LNDR)
    - [ ] Default durasi pengerjaan
    - [ ] **Workflow preference** (optional):
      - [ ] Auto-suggest "Ready" status (default)
      - [ ] Auto-suggest "Done" directly (express mode)
  - [ ] Printer settings (link to printer_settings_screen)
  - [ ] About app (version, developer)
  - [ ] Reset data (with confirmation)

#### Polish
- [ ] **Loading states**
  - [ ] Skeleton loading untuk list
  - [ ] CircularProgressIndicator untuk actions
  - [ ] Overlay loading untuk heavy operations

- [ ] **Error handling**
  - [ ] Try-catch di semua repository methods
  - [ ] User-friendly error messages (bukan "Exception: ...")
  - [ ] Snackbar untuk feedback

- [ ] **Validation**
  - [ ] Form validation lengkap
  - [ ] Input sanitization (trim, lowercase untuk search, dll)
  - [ ] Phone number format validation

- [ ] **Empty states**
  - [ ] Belum ada order
  - [ ] Belum ada paket service
  - [ ] Belum ada laporan
  - [ ] Search no results

- [ ] **Confirmation dialogs**
  - [ ] Delete service
  - [ ] Reset data
  - [ ] Print receipt
  - [ ] Update status order

- [ ] **UX improvements**
  - [ ] Pull to refresh di semua list
  - [ ] Swipe to dismiss/delete (optional)
  - [ ] Quick filters (chip filters)
  - [ ] Auto-save draft (optional)

---

### **FASE 8: Testing & Demo Prep** ⏱️ Hari 6-7

#### Data Generation
- [ ] Create seed data script
  - [ ] 6 default services
  - [ ] 20 dummy orders (various status)
  - [ ] Payments untuk beberapa orders
  - [ ] Date range: last 30 days

#### Testing Checklist
- [ ] **Happy path:**
  - [ ] Setup app pertama kali
  - [ ] Tambah service baru
  - [ ] Buat order baru (full flow)
  - [ ] Print receipt
  - [ ] Share to WA
  - [ ] Update status order
  - [ ] Tambah payment
  - [ ] Lihat laporan harian
  - [ ] Lihat laporan bulanan

- [ ] **Edge cases:**
  - [ ] Order tanpa DP
  - [ ] Order full payment
  - [ ] Customer tanpa nomor HP
  - [ ] Print saat printer not connected
  - [ ] Search dengan keyword kosong
  - [ ] Filter dengan no results

- [ ] **Error scenarios:**
  - [ ] Database error
  - [ ] Printer error
  - [ ] Permission denied
  - [ ] Invalid form input

#### Demo Preparation
- [ ] Buat slide/flow demo
- [ ] Prepare skenario realistic:
  ```
  1. Buka app → Dashboard (ada 5 order ready)
  2. Customer datang (Ibu Siti)
  3. Buat order baru:
     - Cuci Kering 3kg
     - Setrika 2kg
     - Total: Rp 34.000
     - DP: Rp 10.000
  4. Print struk bluetooth
  5. Share ke WA customer
  6. Customer lain ambil cucian → Update status "Done"
  7. Tambah payment pelunasan
  8. Lihat laporan hari ini → Omzet Rp 500.000
  ```
- [ ] Record screencast (backup)
- [ ] Test di real device + printer bluetooth
- [ ] Prepare FAQs

---

## 🎨 Design Guidelines

### Color Palette
```dart
// lib/core/constants/colors.dart
class AppColors {
  // Primary
  static const primary = Color(0xFF2196F3); // Blue
  static const primaryDark = Color(0xFF1976D2);
  static const primaryLight = Color(0xFFBBDEFB);
  
  // Status
  static const statusPending = Color(0xFFFF9800); // Orange
  static const statusProcess = Color(0xFF2196F3); // Blue
  static const statusReady = Color(0xFF4CAF50); // Green
  static const statusDone = Color(0xFF9E9E9E); // Grey
  
  // Semantic
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFF44336);
  static const info = Color(0xFF2196F3);
  
  // Neutral
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
}
```

### Typography
```dart
// Use Google Fonts: Poppins
ThemeData(
  textTheme: GoogleFonts.poppinsTextTheme(),
  // ...
)
```

### Components
- **Cards**: Elevation 2, Radius 12
- **Buttons**: Primary (filled), Secondary (outlined), Text
- **Inputs**: OutlineInputBorder, Radius 8
- **Bottom Navigation**: Fixed 4 items (Dashboard, Orders, Reports, Settings)

---

## 🚨 Common Pitfalls & Solutions

| Problem | Solution |
|---------|----------|
| Invoice number duplikat | UNIQUE constraint + check last number hari itu |
| App crash saat print | Try-catch, cek printer connected sebelum print |
| WA tidak terbuka | Validasi format nomor (62xxx), cek WA installed |
| Database corrupt | Backup otomatis, migration handler |
| Printer ga connect | Common passwords: 0000, 1234, 1111 |
| Layout overflow di small screen | SingleChildScrollView + MediaQuery |
| Slow query di laporan | Add indexes, limit date range |
| ForeignKey constraint fail | Use transaction, check order exists |
| Status update invalid | Validate allowed transitions (getNextStatusOptions) |
| User bingung flow | Kasih label jelas: "Selesai (Ready)" vs "Langsung Selesai" |

---

## 📱 Demo Flow (Webinar)

### Skenario Realistic: "Hari Sibuk di Laundry"

**Waktu: Pagi hari, laundry baru buka**

1. **Owner buka app**
   - Dashboard tampil summary hari ini
   - Ada 5 order status "Ready" (siap diambil)
   - Total omzet kemarin: Rp 800.000

2. **Customer pertama datang (Ibu Siti) - Order Baru Reguler**
   - Tap FAB "Tambah Order"
   - Input:
     - Nama: Ibu Siti
     - HP: 0856-xxxx-xxxx
     - Service:
       - Cuci Kering: 3 kg x Rp 8.000 = Rp 24.000
       - Setrika: 2 kg x Rp 5.000 = Rp 10.000
     - Total: Rp 34.000
     - DP: Rp 10.000 (Cash)
     - Ambil: 18 Januari (3 hari lagi)
   - Tap "Simpan & Print"
   - Status: **Pending**
   - Print struk via bluetooth
   - Share reminder ke WA Ibu Siti

3. **Update Status ke Process**
   - Owner mulai kerjakan cucian Ibu Siti
   - Buka detail order → Update Status → **Process**

4. **Customer kedua (Pak Budi) - Ambil Cucian (Flow Full)**
   - Cari order: "Pak Budi" di search bar
   - Buka detail order
   - Status saat ini: "Ready"
   - Tap "Update Status" → **"Sudah Diambil (Done)"**
   - Sisa pembayaran: Rp 15.000
   - Tap "Tambah Pembayaran" → Rp 15.000 (Cash)
   - Print struk lunas
   - Order selesai

5. **Customer ketiga (Mbak Ani) - Express/Langsung Jadi (Flow Cepat)**
   - Order: Setrika 5 kg
   - Owner langsung kerjakan (customer tunggu 30 menit)
   - Status: Pending → Process
   - Setelah selesai → Update Status → **"Langsung Selesai (Done)"** (skip Ready)
   - Full payment → Done
   - Customer langsung bawa pulang

6. **Selesai Kerjakan Order Ibu Siti**
   - Cucian Ibu Siti sudah selesai
   - Update Status dari Process → **"Selesai (Ready)"**
   - Cucian digantung, tunggu Ibu Siti ambil besok

7. **Owner mau lihat performa**
   - Tap menu "Laporan"
   - Tab "Harian" - Hari ini:
     - Total order: 8
     - Pemasukan: Rp 500.000
     - Pending: 2, Process: 3, Ready: 5, Done: 3
   - Tab "Bulanan" - Januari 2026:
     - Chart omzet 15 hari terakhir (trending naik)
     - Total bulan ini: Rp 8.5 juta
     - Service terlaris: Cuci Setrika (45 order)

**Total waktu demo: 7-10 menit**

**Key Takeaway Demo:**
- ✅ Flow fleksibel: ada yang langsung Done, ada yang lewat Ready
- ✅ Print bluetooth works
- ✅ WhatsApp reminder works
- ✅ Payment tracking akurat
- ✅ Laporan real-time

---

## 🔧 Utilities & Helpers

### Date Formatter
```dart
// lib/core/utils/date_formatter.dart
class DateFormatter {
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }
  
  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(date);
  }
  
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return formatDate(date);
  }
  
  static bool isOverdue(DateTime dueDate) {
    return DateTime.now().isAfter(dueDate);
  }
}
```

### Currency Formatter
```dart
// lib/core/utils/currency_formatter.dart
class CurrencyFormatter {
  static String format(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
  
  static int parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }
}
```

### Invoice Generator
```dart
// lib/core/utils/invoice_generator.dart
class InvoiceGenerator {
  static Future<String> generate() async {
    final today = DateTime.now();
    final dateStr = DateFormat('yyMMdd').format(today); // YYMMDD format
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    
    final db = await DatabaseHelper.instance.database;
    
    // Get settings
    final settingsResult = await db.query(
      'app_settings',
      where: 'key IN (?, ?, ?)',
      whereArgs: ['invoice_prefix', 'last_invoice_date', 'last_invoice_number'],
    );
    
    final settings = Map.fromEntries(
      settingsResult.map((e) => MapEntry(e['key'] as String, e['value'] as String))
    );
    
    final prefix = settings['invoice_prefix'] ?? 'LNDR';
    final lastDate = settings['last_invoice_date'] ?? '';
    final lastNumber = int.parse(settings['last_invoice_number'] ?? '0');
    
    int nextNumber;
    if (lastDate == todayStr) {
      // Same day, increment
      nextNumber = lastNumber + 1;
    } else {
      // New day, reset to 1
      nextNumber = 1;
    }
    
    // Update settings
    await db.update(
      'app_settings',
      {'value': todayStr},
      where: 'key = ?',
      whereArgs: ['last_invoice_date'],
    );
    await db.update(
      'app_settings',
      {'value': nextNumber.toString()},
      where: 'key = ?',
      whereArgs: ['last_invoice_number'],
    );
    
    // Format: LNDR-260115-0001
    return '$prefix-$dateStr-${nextNumber.toString().padLeft(4, '0')}';
  }
}
```

---

## 📖 Additional Resources

### Flutter Bloc Best Practices
- Use Equatable untuk state comparison
- Emit loading sebelum async operations
- Always handle error states
- Close streams di cubit's close()

### SQLite Tips
- Use transactions untuk multi-table inserts
- Add indexes untuk frequent queries
- NEVER store sensitive data plaintext
- Use AUTOINCREMENT dengan bijak (overhead)

### Bluetooth Printing
- Test dengan berbagai merk printer (Epson, Zjiang, GOWELL)
- Default baud rate: 9600
- Max width 58mm: 32 characters
- Use generator.feed(n) untuk spacing

### Performance
- Lazy load lists (ListView.builder)
- Cache frequently accessed data
- Debounce search input
- Paginate large datasets

---

## 🎯 Success Metrics

Aplikasi dianggap sukses jika:
- ✅ Owner bisa input order < 30 detik
- ✅ Print struk berhasil 95%+ waktu
- ✅ Share WA work tanpa manual copy-paste
- ✅ Laporan harian akurat 100%
- ✅ Zero data loss (backup mechanism)
- ✅ Onboarding owner < 5 menit

---

## 📝 Notes for Claude AI

Ketika develop aplikasi ini, prioritas:

1. **Functionality > Beauty**
   - Working features lebih penting dari animasi fancy
   - Simple UI tapi jelas dan mudah dipakai

2. **UMKM Mindset**
   - Owner laundry bukan tech-savvy
   - Tombol besar, text jelas, flow simple
   - Minimize steps untuk common tasks

3. **Offline First**
   - Semua fitur harus work tanpa internet
   - Bluetooth printer = no internet needed
   - WhatsApp share = bonus feature, bukan core

4. **Real Business Flow**
   - Ikuti flow kerja laundry real dengan **2 pilihan workflow**:
   
   ```
   FLOW 1: EXPRESS/LANGSUNG (Customer tunggu/ambil hari itu)
   ┌─────────┐    ┌─────────┐    ┌──────┐
   │ Pending │───→│ Process │───→│ Done │
   └─────────┘    └─────────┘    └──────┘
   
   FLOW 2: REGULAR (Customer ambil besok/lusa)
   ┌─────────┐    ┌─────────┐    ┌───────┐    ┌──────┐
   │ Pending │───→│ Process │───→│ Ready │───→│ Done │
   └─────────┘    └─────────┘    └───────┘    └──────┘
                                   (siap 
                                   diambil)
   ```
   
   - Status "Ready" = OPTIONAL (owner pilih sendiri)
   - DP/pelunasan bertahap = normal practice
   - Nota = bukti transaksi (harus presisi)

5. **Indonesian Context**
   - Currency: Rupiah (Rp), no decimal
   - Phone: 08xx atau 62xx format
   - Language: Mix Indonesian + English OK
   - Date: dd MMM yyyy (15 Jan 2026)

---

**Ready to start coding? Let's build something that actually helps Indonesian UMKM! 🚀**
