# Development Todolist - LaundryFull Offline App

> **Project**: Aplikasi Kasir Laundry Offline untuk UMKM Indonesia
> **Tech Stack**: Flutter + SQLite + Cubit
> **Status**: In Progress

---

## Daftar Fase

| No | Fase | Deskripsi |
|----|------|-----------|
| 1 | Setup Project & Database | Foundation, folder structure, database |
| 1.5 | Authentication | Login owner/kasir, role-based access |
| 2 | Service Management | CRUD paket layanan laundry |
| 3 | Order Management | Core feature - kelola order |
| 4 | Customer Management | Data pelanggan, export, broadcast WA |
| 5 | Printer Bluetooth | Print struk thermal |
| 6 | Share WhatsApp (Order) | Share nota ke customer |
| 7 | Reports & Dashboard | Laporan harian/mingguan/bulanan/custom + export Excel/CSV + share WA |
| 8 | Settings & Polish | Pengaturan app, UI polish |
| 9 | Testing & Demo | Testing & persiapan demo |

---

## FASE 1: Setup Project & Database

### 1.1 Project Setup
- [ ] Create Flutter project dengan nama `laundryfull_offline`
- [ ] Setup dependencies di `pubspec.yaml`:
  - [ ] flutter_bloc: ^8.1.3
  - [ ] equatable: ^2.0.5
  - [ ] sqflite: ^2.3.0
  - [ ] path: ^1.8.3
  - [ ] intl: ^0.18.1
  - [ ] uuid: ^4.1.0
  - [ ] blue_thermal_printer: ^1.2.2
  - [ ] esc_pos_utils: ^1.1.0
  - [ ] image: ^4.1.3
  - [ ] share_plus: ^7.2.1
  - [ ] permission_handler: ^11.0.1
  - [ ] path_provider: ^2.1.1
  - [ ] google_fonts: ^6.1.0
  - [ ] fl_chart: ^0.65.0
- [ ] Create folder structure:
  - [ ] `lib/core/constants/`
  - [ ] `lib/core/utils/`
  - [ ] `lib/core/exceptions/`
  - [ ] `lib/data/database/`
  - [ ] `lib/data/models/`
  - [ ] `lib/data/repositories/`
  - [ ] `lib/logic/cubits/`
  - [ ] `lib/presentation/screens/`
  - [ ] `lib/presentation/widgets/`
  - [ ] `assets/images/`
  - [ ] `assets/icons/`

### 1.2 Constants & Theme
- [ ] `lib/core/constants/app_constants.dart` - App config values
- [ ] `lib/core/constants/colors.dart` - Color palette (primary, status colors, semantic colors)

### 1.3 Database Setup
- [ ] `lib/data/database/database_helper.dart`:
  - [ ] Create DatabaseHelper singleton class
  - [ ] Implement `initDatabase()` method
  - [ ] Create table: `users` (untuk auth)
  - [ ] Create table: `customers` (data pelanggan)
  - [ ] Create table: `orders`
  - [ ] Create table: `order_items`
  - [ ] Create table: `services`
  - [ ] Create table: `payments`
  - [ ] Create table: `app_settings`
  - [ ] Add indexes untuk performa
  - [ ] Implement migration handler (`onUpgrade`)
  - [ ] Seed default data (6 services + app settings + default owner)

### 1.4 Models
- [ ] `lib/data/models/order.dart`:
  - [ ] Order class dengan semua fields
  - [ ] `toMap()` dan `fromMap()` methods
  - [ ] `copyWith()` method
  - [ ] `OrderStatus` enum (pending, process, ready, done)
  - [ ] `getNextStatusOptions()` method untuk flexible workflow
  - [ ] Equatable implementation
- [ ] `lib/data/models/order_item.dart`:
  - [ ] OrderItem class
  - [ ] `toMap()` dan `fromMap()` methods
- [ ] `lib/data/models/service.dart`:
  - [ ] Service class
  - [ ] `toMap()` dan `fromMap()` methods
- [ ] `lib/data/models/payment.dart`:
  - [ ] Payment class
  - [ ] `toMap()` dan `fromMap()` methods
  - [ ] PaymentMethod enum (cash, transfer, qris)
- [ ] `lib/data/models/app_setting.dart`:
  - [ ] AppSetting class
  - [ ] `toMap()` dan `fromMap()` methods
- [ ] `lib/data/models/user.dart`:
  - [ ] User class (id, username, password_hash, role, name, is_active)
  - [ ] `toMap()` dan `fromMap()` methods
  - [ ] UserRole enum (owner, kasir)
- [ ] `lib/data/models/customer.dart`:
  - [ ] Customer class (id, name, phone, address, notes, total_orders, total_spent, created_at)
  - [ ] `toMap()` dan `fromMap()` methods

### 1.5 Utilities
- [ ] `lib/core/utils/date_formatter.dart`:
  - [ ] `formatDate()` - dd MMM yyyy format
  - [ ] `formatDateTime()` - dd MMM yyyy HH:mm
  - [ ] `formatRelative()` - Hari ini, Kemarin, dll
  - [ ] `isOverdue()` - Check due date
- [ ] `lib/core/utils/currency_formatter.dart`:
  - [ ] `format()` - Rp x.xxx format
  - [ ] `parse()` - String to int
- [ ] `lib/core/utils/invoice_generator.dart`:
  - [ ] `generate()` - Format: LNDR-YYMMDD-NNNN
  - [ ] Auto reset daily
- [ ] `lib/core/utils/password_helper.dart`:
  - [ ] `hashPassword(String password)` - Hash password dengan salt
  - [ ] `verifyPassword(String password, String hash)` - Verify password
- [ ] `lib/core/exceptions/database_exception.dart`:
  - [ ] Custom exception class untuk database errors

### 1.6 Testing Database
- [ ] Test insert/read/update/delete operations
- [ ] Verify foreign key constraints work
- [ ] Test transaction rollback

---

## FASE 1.5: Authentication (Login Owner & Kasir)

### 1.5.1 Database Schema - Users
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL, -- owner, kasir
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Default owner account (password: admin123)
INSERT INTO users (username, password_hash, name, role) VALUES
('owner', '<hashed_password>', 'Owner Laundry', 'owner');
```

### 1.5.2 Repository
- [ ] `lib/data/repositories/auth_repository.dart`:
  - [ ] `login(String username, String password)` - Validate & return User
  - [ ] `logout()` - Clear session
  - [ ] `getCurrentUser()` - Get logged-in user from session
  - [ ] `isLoggedIn()` - Check session status
- [ ] `lib/data/repositories/user_repository.dart`:
  - [ ] `getAllUsers()` - Get all users (owner only)
  - [ ] `getUserById(int id)` - Get specific user
  - [ ] `createUser(User user)` - Add new kasir/owner
  - [ ] `updateUser(User user)` - Update user info
  - [ ] `deleteUser(int id)` - Soft delete (is_active = 0)
  - [ ] `changePassword(int id, String newPassword)` - Update password

### 1.5.3 Session Storage
- [ ] Tambah dependency: `shared_preferences: ^2.2.2`
- [ ] `lib/core/services/session_service.dart`:
  - [ ] `saveSession(User user)` - Save user ID to SharedPreferences
  - [ ] `getSession()` - Get saved user ID
  - [ ] `clearSession()` - Remove session data

### 1.5.4 Cubit
- [ ] `lib/logic/cubits/auth/auth_state.dart`:
  - [ ] AuthInitial state
  - [ ] AuthLoading state
  - [ ] AuthAuthenticated state (with User)
  - [ ] AuthUnauthenticated state
  - [ ] AuthError state (with message)
- [ ] `lib/logic/cubits/auth/auth_cubit.dart`:
  - [ ] `checkAuthStatus()` - Check on app start
  - [ ] `login(String username, String password)` - Login
  - [ ] `logout()` - Logout & clear session
  - [ ] `currentUser` getter - Get current user

### 1.5.5 UI - Login
- [ ] `lib/presentation/screens/auth/login_screen.dart`:
  - [ ] Logo/branding laundry
  - [ ] TextField: Username
  - [ ] TextField: Password (obscured)
  - [ ] Checkbox: Remember me (optional)
  - [ ] Button: Login
  - [ ] Error message display
  - [ ] Loading state

### 1.5.6 UI - User Management (Owner Only)
- [ ] `lib/presentation/screens/settings/user_management_screen.dart`:
  - [ ] List semua user (owner & kasir)
  - [ ] Add new user button
  - [ ] Edit user
  - [ ] Activate/Deactivate user
  - [ ] Reset password
- [ ] `lib/presentation/screens/settings/user_form_screen.dart`:
  - [ ] Form field: Username
  - [ ] Form field: Nama lengkap
  - [ ] Dropdown: Role (owner/kasir)
  - [ ] Form field: Password (for new user)
  - [ ] Validation

### 1.5.7 Role-Based Access Control
- [ ] Define permissions per role:
  ```
  OWNER:
  ✅ Dashboard - Full access
  ✅ Orders - Full CRUD
  ✅ Services - Full CRUD
  ✅ Customers - Full access + export
  ✅ Reports - Full access
  ✅ Settings - Full access
  ✅ User Management - Full CRUD

  KASIR:
  ✅ Dashboard - View only
  ✅ Orders - Create, View, Update status
  ❌ Orders - Delete (tidak bisa)
  ❌ Services - View only (tidak bisa edit)
  ✅ Customers - View only
  ❌ Reports - Tidak bisa akses
  ❌ Settings - Tidak bisa akses
  ❌ User Management - Tidak bisa akses
  ```
- [ ] `lib/core/utils/permission_helper.dart`:
  - [ ] `canAccessReports(UserRole role)` - Check report access
  - [ ] `canManageServices(UserRole role)` - Check service CRUD
  - [ ] `canManageUsers(UserRole role)` - Check user management
  - [ ] `canDeleteOrder(UserRole role)` - Check delete permission
  - [ ] `canExportData(UserRole role)` - Check export permission

### 1.5.8 App Flow dengan Auth
- [ ] Modify `main.dart`:
  - [ ] Check auth status on startup
  - [ ] Redirect ke LoginScreen jika belum login
  - [ ] Redirect ke Dashboard jika sudah login
- [ ] Add logout button di Settings
- [ ] Show current user info di drawer/header

---

## FASE 2: Service Management

### 2.1 Repository
- [ ] `lib/data/repositories/service_repository.dart`:
  - [ ] `getAllServices()` - Get all active services
  - [ ] `getServiceById(int id)` - Get specific service
  - [ ] `createService(Service service)` - Add new service
  - [ ] `updateService(Service service)` - Update existing
  - [ ] `deleteService(int id)` - Soft delete (is_active = 0)

### 2.2 Cubit
- [ ] `lib/logic/cubits/service/service_state.dart`:
  - [ ] ServiceInitial state
  - [ ] ServiceLoading state
  - [ ] ServiceLoaded state (with List<Service>)
  - [ ] ServiceError state (with message)
- [ ] `lib/logic/cubits/service/service_cubit.dart`:
  - [ ] `loadServices()` - Load all services
  - [ ] `addService(Service service)` - Validate & add
  - [ ] `updateService(Service service)` - Update
  - [ ] `deleteService(int id)` - Delete with confirmation

### 2.3 UI - Service Management
- [ ] `lib/presentation/widgets/service_card.dart`:
  - [ ] Display: nama, harga, durasi, unit
  - [ ] Edit button
  - [ ] Delete button
- [ ] `lib/presentation/screens/services/service_list_screen.dart`:
  - [ ] AppBar dengan title + add button
  - [ ] ListView.builder dengan ServiceCard
  - [ ] Empty state (belum ada paket)
  - [ ] Pull to refresh
- [ ] `lib/presentation/screens/services/service_form_screen.dart`:
  - [ ] Form field: Nama service
  - [ ] Dropdown: Unit (kg/pcs)
  - [ ] Form field: Harga
  - [ ] Form field: Durasi (hari)
  - [ ] Validation (semua required, harga > 0)
  - [ ] Save button dengan loading state

---

## FASE 3: Order Management

### 3.1 Repositories
- [ ] `lib/data/repositories/order_repository.dart`:
  - [ ] `getAllOrders({OrderStatus? status})` - Filter by status
  - [ ] `getOrderById(int id)` - With items & payments (JOIN)
  - [ ] `createOrder(Order order, List<OrderItem> items)` - Transaction
  - [ ] `updateOrderStatus(int id, OrderStatus status)` - Update status
  - [ ] `searchOrders(String query)` - By customer name/phone/invoice
  - [ ] `getOrdersByDateRange(DateTime start, DateTime end)` - For reports
  - [ ] `deleteOrder(int id)` - Delete order
- [ ] `lib/data/repositories/payment_repository.dart`:
  - [ ] `getPaymentsByOrderId(int orderId)` - Get all payments
  - [ ] `addPayment(Payment payment)` - Add payment & update order.paid
  - [ ] `getTotalPaidAmount(int orderId)` - Sum payments
- [ ] `lib/data/repositories/settings_repository.dart`:
  - [ ] `getSetting(String key)` - Get single setting
  - [ ] `setSetting(String key, String value)` - Update setting
  - [ ] `getAllSettings()` - Get all settings

### 3.2 Cubit
- [ ] `lib/logic/cubits/order/order_state.dart`:
  - [ ] OrderInitial state
  - [ ] OrderLoading state
  - [ ] OrderLoaded state (with List<Order>)
  - [ ] OrderDetailLoaded state (with Order + items + payments)
  - [ ] OrderCreated state
  - [ ] OrderError state
- [ ] `lib/logic/cubits/order/order_cubit.dart`:
  - [ ] `loadOrders({OrderStatus? status})` - Load & filter
  - [ ] `loadOrderDetail(int id)` - Load with items & payments
  - [ ] `createOrder(...)` - Validate, generate invoice, save
  - [ ] `updateStatus(int id, OrderStatus newStatus)` - Update
  - [ ] `addPayment(Payment payment)` - Add payment
  - [ ] `searchOrders(String query)` - Search

### 3.3 UI - Widgets
- [ ] `lib/presentation/widgets/status_badge.dart`:
  - [ ] Color coded per status
  - [ ] Pending = orange
  - [ ] Process = blue
  - [ ] Ready = green
  - [ ] Done = grey
  - [ ] Icon + text display
- [ ] `lib/presentation/widgets/order_card.dart`:
  - [ ] Display: Invoice, Customer name, Status badge
  - [ ] Display: Total harga, DP/Lunas info
  - [ ] Display: Due date (with overdue warning)
  - [ ] onTap handler untuk navigate to detail
- [ ] `lib/presentation/widgets/custom_button.dart`:
  - [ ] Primary button style
  - [ ] Secondary button style
  - [ ] Loading state
- [ ] `lib/presentation/widgets/loading_overlay.dart`:
  - [ ] Full screen loading overlay

### 3.4 UI - Screens
- [ ] `lib/presentation/screens/dashboard/dashboard_screen.dart`:
  - [ ] Summary cards: Total pending, Process, Ready, Done (hari ini)
  - [ ] Quick stats: Total omzet hari ini, Total order bulan ini
  - [ ] Quick actions: Tambah order, Lihat laporan
  - [ ] Recent orders (5 terakhir)
- [ ] `lib/presentation/screens/orders/order_list_screen.dart`:
  - [ ] Tabs/Filter by status (Semua, Pending, Process, Ready, Done)
  - [ ] ListView dengan OrderCard
  - [ ] Search bar (by nama/HP/invoice)
  - [ ] FAB: Tambah order baru
  - [ ] Pull to refresh
- [ ] `lib/presentation/screens/orders/order_form_screen.dart`:
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
    - [ ] Total items display
    - [ ] Total berat/pcs display
    - [ ] TOTAL HARGA (bold, besar)
  - [ ] Additional info:
    - [ ] DatePicker: Tanggal ambil
    - [ ] TextField: Catatan (optional)
  - [ ] DP/Bayar section:
    - [ ] TextField: Jumlah bayar
    - [ ] Dropdown: Metode bayar (Cash, Transfer, QRIS)
  - [ ] Button: Simpan & Print
  - [ ] Validation: min 1 item, nama required
- [ ] `lib/presentation/screens/orders/order_detail_screen.dart`:
  - [ ] Header: Invoice number, Status badge, Date
  - [ ] Customer info section
  - [ ] Items list (read-only)
  - [ ] Payment history section
  - [ ] Total & remaining payment display
  - [ ] Actions:
    - [ ] Update status button (with dialog)
    - [ ] Add payment button
    - [ ] Print receipt button
    - [ ] Share to WhatsApp button
  - [ ] Notes display

---

## FASE 4: Customer Management

### 4.1 Database Schema - Customers
```sql
CREATE TABLE customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT UNIQUE,
  address TEXT,
  notes TEXT,
  total_orders INTEGER DEFAULT 0,
  total_spent INTEGER DEFAULT 0,
  last_order_date TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_name ON customers(name);
```

### 4.2 Relasi Order-Customer
- [ ] Update table `orders`:
  - [ ] Tambah kolom `customer_id INTEGER` (foreign key ke customers)
  - [ ] Tetap simpan `customer_name` dan `customer_phone` untuk historical data
- [ ] Auto-create customer saat buat order baru (jika phone belum ada)
- [ ] Auto-update `total_orders` dan `total_spent` di customer setelah order selesai

### 4.3 Repository
- [ ] `lib/data/repositories/customer_repository.dart`:
  - [ ] `getAllCustomers()` - Get all customers
  - [ ] `getCustomerById(int id)` - Get specific customer
  - [ ] `getCustomerByPhone(String phone)` - Find by phone number
  - [ ] `createCustomer(Customer customer)` - Add new customer
  - [ ] `updateCustomer(Customer customer)` - Update customer info
  - [ ] `deleteCustomer(int id)` - Delete customer (soft delete)
  - [ ] `searchCustomers(String query)` - Search by name/phone
  - [ ] `getTopCustomers({int limit})` - Get customers by total_spent
  - [ ] `getCustomerOrderHistory(int customerId)` - Get all orders by customer
  - [ ] `updateCustomerStats(int customerId)` - Recalculate total_orders & total_spent

### 4.4 Cubit
- [ ] `lib/logic/cubits/customer/customer_state.dart`:
  - [ ] CustomerInitial state
  - [ ] CustomerLoading state
  - [ ] CustomerLoaded state (with List<Customer>)
  - [ ] CustomerDetailLoaded state (with Customer + order history)
  - [ ] CustomerError state
- [ ] `lib/logic/cubits/customer/customer_cubit.dart`:
  - [ ] `loadCustomers()` - Load all customers
  - [ ] `loadCustomerDetail(int id)` - Load with order history
  - [ ] `searchCustomers(String query)` - Search
  - [ ] `addCustomer(Customer customer)` - Add new
  - [ ] `updateCustomer(Customer customer)` - Update
  - [ ] `deleteCustomer(int id)` - Delete

### 4.5 UI - Customer List
- [ ] `lib/presentation/screens/customers/customer_list_screen.dart`:
  - [ ] AppBar dengan title + search + add button
  - [ ] Search bar (by nama/phone)
  - [ ] ListView dengan CustomerCard
  - [ ] Sort options: Nama A-Z, Total Order, Total Spent
  - [ ] Filter: Semua, Aktif (punya order dalam 30 hari), Tidak aktif
  - [ ] Pull to refresh
  - [ ] Empty state
  - [ ] FAB: Export / Broadcast WA

### 4.6 UI - Customer Card Widget
- [ ] `lib/presentation/widgets/customer_card.dart`:
  - [ ] Display: Nama, No HP
  - [ ] Display: Total orders, Total spent
  - [ ] Display: Last order date
  - [ ] Badge: "Pelanggan Setia" jika total_orders > 10
  - [ ] Quick actions: WhatsApp, Call, View Detail
  - [ ] onTap: Navigate to detail

### 4.7 UI - Customer Detail
- [ ] `lib/presentation/screens/customers/customer_detail_screen.dart`:
  - [ ] Header: Nama, Phone, Address
  - [ ] Stats cards:
    - [ ] Total Orders
    - [ ] Total Spent (Rp)
    - [ ] Rata-rata per order
    - [ ] Member since
  - [ ] Order History list (recent first)
  - [ ] Actions:
    - [ ] Edit customer
    - [ ] WhatsApp customer
    - [ ] Call customer
    - [ ] Delete customer (owner only)

### 4.8 UI - Customer Form
- [ ] `lib/presentation/screens/customers/customer_form_screen.dart`:
  - [ ] Form field: Nama (required)
  - [ ] Form field: No HP (required, unique validation)
  - [ ] Form field: Alamat (optional)
  - [ ] Form field: Catatan (optional)
  - [ ] Validation: phone format, unique phone check
  - [ ] Save button

### 4.9 Export Customer Data
- [ ] `lib/core/services/export_service.dart`:
  - [ ] `exportCustomersToCSV(List<Customer> customers)`:
    - [ ] Format: Nama, No HP, Alamat, Total Order, Total Spent
    - [ ] Save ke Downloads folder
    - [ ] Return file path
  - [ ] `exportCustomersToExcel(List<Customer> customers)` (optional):
    - [ ] Tambah dependency: `excel: ^4.0.2`
    - [ ] Format lebih bagus dengan header styling
- [ ] UI: Export button di customer_list_screen
  - [ ] Dialog pilih format (CSV/Excel)
  - [ ] Filter: Export semua / Export yang difilter
  - [ ] Share file setelah export

### 4.10 Broadcast WhatsApp
- [ ] `lib/core/services/broadcast_service.dart`:
  - [ ] `generateBroadcastMessage(String template, Customer customer)`:
    - [ ] Replace placeholder: {nama}, {total_order}, dll
  - [ ] `openWhatsAppBroadcast(List<Customer> customers, String message)`:
    - [ ] Option 1: Buka WA satu-satu (deep link per customer)
    - [ ] Option 2: Copy semua nomor ke clipboard + template message
- [ ] UI: Broadcast WA di customer_list_screen
  - [ ] Select multiple customers (checkbox mode)
  - [ ] "Select All" / "Deselect All"
  - [ ] Input/pilih template message:
    - [ ] Promo template
    - [ ] Reminder template
    - [ ] Custom template
  - [ ] Preview message
  - [ ] Button: "Broadcast ke X customer"

### 4.11 Template Message untuk Broadcast
- [ ] Default templates (stored di app_settings):
  ```
  PROMO:
  Halo {nama}! 👋

  Ada PROMO SPESIAL untuk pelanggan setia kami!
  🎉 Diskon 20% untuk semua layanan
  📅 Berlaku s/d [tanggal]

  Yuk, cuci di tempat kami!
  Terima kasih 🙏

  REMINDER:
  Halo {nama}! 👋

  Sudah lama nih tidak cuci di tempat kami 😊
  Kami kangen melayani Anda!

  Mampir lagi ya, ada banyak layanan baru!
  Terima kasih 🙏

  UCAPAN:
  Halo {nama}! 👋

  Terima kasih sudah menjadi pelanggan setia kami!
  Total {total_order} order dengan nilai Rp {total_spent}

  Semoga kami bisa terus melayani Anda!
  🙏
  ```
- [ ] UI: Template management di Settings (owner only)

### 4.12 Integration dengan Order Form
- [ ] Update `order_form_screen.dart`:
  - [ ] Autocomplete customer name dari database
  - [ ] Jika phone match, auto-fill customer data
  - [ ] Button "Pilih Customer" → open customer picker dialog
  - [ ] Jika customer baru, auto-create setelah order saved

---

## FASE 5: Printer Bluetooth

### 5.1 Cubit
- [ ] `lib/logic/cubits/printer/printer_state.dart`:
  - [ ] PrinterDisconnected state
  - [ ] PrinterConnecting state
  - [ ] PrinterConnected state (with device info)
  - [ ] PrinterScanning state
  - [ ] PrinterError state
- [ ] `lib/logic/cubits/printer/printer_cubit.dart`:
  - [ ] `scanDevices()` - Scan bluetooth devices
  - [ ] `connectDevice(BluetoothDevice device)` - Connect
  - [ ] `disconnectDevice()` - Disconnect
  - [ ] `printReceipt(Order order)` - Print formatted receipt
  - [ ] `testPrint()` - Print test page

### 5.2 Printer Service
- [ ] `lib/core/services/printer_service.dart`:
  - [ ] `generateReceiptBytes(Order order)` - Format ESC/POS
  - [ ] Handle 58mm paper width (32 chars)
  - [ ] Format sections:
    - [ ] Header (nama laundry, alamat, telp)
    - [ ] Invoice info
    - [ ] Customer info
    - [ ] Items list with prices
    - [ ] Total, DP, Sisa
    - [ ] Due date
    - [ ] Footer
  - [ ] Handle printer errors

### 5.3 UI
- [ ] `lib/presentation/screens/settings/printer_settings_screen.dart`:
  - [ ] Button: Scan devices
  - [ ] List available bluetooth devices
  - [ ] Connection status indicator
  - [ ] Button: Connect/Disconnect
  - [ ] Button: Test print
  - [ ] Auto-save printer address to settings

### 5.4 Permissions
- [ ] Setup Android bluetooth permissions di AndroidManifest.xml
- [ ] Request runtime permissions
- [ ] Handle permission denied dengan dialog info

---

## FASE 6: Share WhatsApp (Order)

### 6.1 WhatsApp Service
- [ ] `lib/core/services/whatsapp_service.dart`:
  - [ ] `shareReceipt(Order order)` - Generate text & send
  - [ ] Format message template dengan:
    - [ ] Customer name
    - [ ] Invoice number
    - [ ] Tanggal order
    - [ ] Detail cucian
    - [ ] Total, DP, Sisa
    - [ ] Tanggal ambil
  - [ ] Format nomor HP (0856xxx → 62856xxx)
  - [ ] Deep link ke WhatsApp
  - [ ] Handle WA not installed

### 6.2 Integration
- [ ] Add "Share to WA" button di order_detail_screen
- [ ] Add "Share to WA" option after create order
- [ ] Validation: customer harus punya nomor HP
- [ ] Error handling dengan snackbar

---

## FASE 7: Reports & Dashboard

### 7.1 Repository
- [ ] `lib/data/repositories/report_repository.dart`:
  - [ ] `getDailySummary(DateTime date)`:
    - [ ] Total orders per status
    - [ ] Total revenue (sum payments)
    - [ ] Revenue by payment method
  - [ ] `getWeeklySummary(DateTime startOfWeek)`:
    - [ ] Daily revenue untuk 7 hari
    - [ ] Total orders & revenue
  - [ ] `getMonthlySummary(int year, int month)`:
    - [ ] Daily revenue data untuk chart
    - [ ] Total orders
    - [ ] Total revenue
  - [ ] `getCustomRangeSummary(DateTime start, DateTime end)`:
    - [ ] Custom date range report
    - [ ] Daily breakdown
  - [ ] `getTopServices(DateTime start, DateTime end)` - Service terlaris
  - [ ] `getOrdersForReport(DateTime start, DateTime end)` - Get orders untuk export

### 7.2 Cubit
- [ ] `lib/logic/cubits/report/report_state.dart`:
  - [ ] ReportInitial state
  - [ ] ReportLoading state
  - [ ] DailyReportLoaded state
  - [ ] WeeklyReportLoaded state
  - [ ] MonthlyReportLoaded state
  - [ ] CustomReportLoaded state
  - [ ] ReportExporting state
  - [ ] ReportError state
- [ ] `lib/logic/cubits/report/report_cubit.dart`:
  - [ ] `loadDailyReport(DateTime date)` - Load harian
  - [ ] `loadWeeklyReport(DateTime startOfWeek)` - Load mingguan
  - [ ] `loadMonthlyReport(int year, int month)` - Load bulanan
  - [ ] `loadCustomReport(DateTime start, DateTime end)` - Load custom range
  - [ ] `exportReport(ReportType type, DateTime start, DateTime end)` - Export

### 7.3 UI - Report Screen
- [ ] `lib/presentation/screens/reports/report_screen.dart`:
  - [ ] Tab: Harian
    - [ ] Date picker
    - [ ] Summary cards (total order, total pemasukan)
    - [ ] Orders by status breakdown
    - [ ] Revenue by payment method
    - [ ] List orders hari itu
    - [ ] **Share & Export buttons**
  - [ ] Tab: Mingguan
    - [ ] Week picker (pilih minggu)
    - [ ] Bar chart omzet per hari (7 hari)
    - [ ] Summary cards
    - [ ] **Share & Export buttons**
  - [ ] Tab: Bulanan
    - [ ] Month/Year picker
    - [ ] Line chart omzet per hari (fl_chart)
    - [ ] Summary cards (total order, revenue, rata-rata)
    - [ ] Top services list
    - [ ] **Share & Export buttons**
  - [ ] Tab: Custom
    - [ ] Date range picker (start - end)
    - [ ] Summary cards
    - [ ] Chart (jika range <= 31 hari)
    - [ ] **Share & Export buttons**

### 7.4 Export Laporan ke Excel/CSV
- [ ] `lib/core/services/report_export_service.dart`:
  - [ ] `exportToExcel(ReportData data, String filename)`:
    - [ ] Tambah dependency: `excel: ^4.0.2`
    - [ ] Sheet 1: Summary (Total order, revenue, dll)
    - [ ] Sheet 2: Detail orders (Invoice, Customer, Items, Total, Status)
    - [ ] Sheet 3: Payment breakdown
    - [ ] Header styling (bold, background color)
    - [ ] Auto column width
    - [ ] Save ke Downloads folder
  - [ ] `exportToCSV(ReportData data, String filename)`:
    - [ ] Format simple CSV
    - [ ] Untuk kompatibilitas lebih luas
  - [ ] `generateReportFilename(ReportType type, DateTime start, DateTime end)`:
    - [ ] Format: Laporan_Harian_15Jan2026.xlsx
    - [ ] Format: Laporan_Bulanan_Jan2026.xlsx
- [ ] UI: Export dialog
  - [ ] Pilih format: Excel / CSV
  - [ ] Preview filename
  - [ ] Button: Export & Save
  - [ ] Button: Export & Share

### 7.5 Share Laporan ke WhatsApp
- [ ] `lib/core/services/report_share_service.dart`:
  - [ ] `generateReportSummaryText(ReportData data)`:
    ```
    📊 *LAPORAN HARIAN*
    📅 15 Januari 2026

    💰 *Total Pemasukan:* Rp 850.000
    📦 *Total Order:* 12

    *Breakdown Status:*
    ✅ Selesai: 8
    🔄 Proses: 3
    ⏳ Pending: 1

    *Metode Pembayaran:*
    💵 Cash: Rp 500.000
    🏦 Transfer: Rp 250.000
    📱 QRIS: Rp 100.000

    ---
    Generated by LaundryFull App
    ```
  - [ ] `shareReportToWhatsApp(String summary)`:
    - [ ] Open WA dengan text summary
  - [ ] `shareReportFileToWhatsApp(File file)`:
    - [ ] Share file Excel/CSV via WA
- [ ] UI: Share options
  - [ ] Share as Text (ringkasan)
  - [ ] Share as File (Excel/CSV)
  - [ ] Share to specific number (optional)

### 7.6 Quick Share Actions di Report Screen
- [ ] Bottom action bar dengan:
  - [ ] Button: "Share WA" → share text summary
  - [ ] Button: "Export Excel" → save & share Excel
  - [ ] Button: "Export CSV" → save & share CSV
- [ ] Long press on report → quick share menu

## FASE 8: Settings & Polish

### 8.1 Settings Screen
- [ ] `lib/presentation/screens/settings/settings_screen.dart`:
  - [ ] Laundry info section:
    - [ ] Edit nama laundry
    - [ ] Edit alamat
    - [ ] Edit nomor HP
  - [ ] App preferences section:
    - [ ] Invoice prefix setting
    - [ ] Default durasi pengerjaan
  - [ ] Printer settings (link to printer_settings_screen)
  - [ ] About app section (version, developer info)
  - [ ] Reset data button (with confirmation dialog)

### 8.2 Main App Setup
- [ ] `lib/main.dart`:
  - [ ] Setup MultiBlocProvider
  - [ ] Initialize database
  - [ ] Setup MaterialApp dengan theme
  - [ ] Configure Google Fonts
- [ ] Bottom Navigation dengan 4 tabs:
  - [ ] Dashboard
  - [ ] Orders
  - [ ] Reports
  - [ ] Settings

### 8.3 Polish - Loading States
- [ ] Skeleton loading untuk lists
- [ ] CircularProgressIndicator untuk actions
- [ ] Overlay loading untuk heavy operations

### 8.4 Polish - Error Handling
- [ ] Try-catch di semua repository methods
- [ ] User-friendly error messages
- [ ] Snackbar untuk feedback

### 8.5 Polish - Empty States
- [ ] Empty state: Belum ada order
- [ ] Empty state: Belum ada paket service
- [ ] Empty state: Belum ada laporan
- [ ] Empty state: Search no results

### 8.6 Polish - Confirmation Dialogs
- [ ] Dialog: Delete service
- [ ] Dialog: Reset data
- [ ] Dialog: Update status order

### 8.7 Polish - UX Improvements
- [ ] Pull to refresh di semua list screens
- [ ] Input validation dengan real-time feedback
- [ ] Phone number format auto-correction

---

## FASE 9: Testing & Demo Prep

### 9.1 Data Generation
- [ ] Create seed data script:
  - [ ] 6 default services
  - [ ] 20 dummy orders (various status)
  - [ ] Payments untuk beberapa orders
  - [ ] Date range: last 30 days
  - [ ] Dummy customers (15-20 customers)
  - [ ] Default users (1 owner, 2 kasir)

### 9.2 Testing - Happy Path
- [ ] Test: Login sebagai owner
- [ ] Test: Login sebagai kasir
- [ ] Test: Setup app pertama kali
- [ ] Test: Tambah service baru
- [ ] Test: Buat order baru (full flow)
- [ ] Test: Print receipt
- [ ] Test: Share to WhatsApp
- [ ] Test: Update status order (Pending → Process → Ready → Done)
- [ ] Test: Update status order (Pending → Process → Done) - express flow
- [ ] Test: Tambah payment
- [ ] Test: Lihat laporan harian
- [ ] Test: Lihat laporan bulanan
- [ ] Test: Export laporan ke Excel
- [ ] Test: Share laporan ke WA
- [ ] Test: Lihat daftar customer
- [ ] Test: Export customer ke CSV
- [ ] Test: Broadcast WA ke multiple customers

### 9.3 Testing - Edge Cases
- [ ] Test: Order tanpa DP
- [ ] Test: Order full payment langsung
- [ ] Test: Customer tanpa nomor HP
- [ ] Test: Print saat printer not connected
- [ ] Test: Search dengan keyword kosong
- [ ] Test: Filter dengan no results
- [ ] Test: Login dengan password salah
- [ ] Test: Kasir akses menu owner-only
- [ ] Test: Export laporan tanpa data

### 9.4 Testing - Error Scenarios
- [ ] Test: Database error handling
- [ ] Test: Printer error handling
- [ ] Test: Permission denied handling
- [ ] Test: Invalid form input handling

### 9.5 Demo Preparation
- [ ] Prepare demo scenario script
- [ ] Test di real Android device
- [ ] Test dengan printer bluetooth real
- [ ] Record backup screencast
- [ ] Prepare FAQ answers

---

## Progress Tracking

| Fase | Status | Completion |
|------|--------|------------|
| FASE 1: Setup Project & Database | Not Started | 0% |
| FASE 1.5: Authentication | Not Started | 0% |
| FASE 2: Service Management | Not Started | 0% |
| FASE 3: Order Management | Not Started | 0% |
| FASE 4: Customer Management | Not Started | 0% |
| FASE 5: Printer Bluetooth | Not Started | 0% |
| FASE 6: Share WhatsApp (Order) | Not Started | 0% |
| FASE 7: Reports & Dashboard | Not Started | 0% |
| FASE 8: Settings & Polish | Not Started | 0% |
| FASE 9: Testing & Demo | Not Started | 0% |

---

## Notes

### Priority Order
1. FASE 1 - Foundation & Database (harus selesai dulu)
2. FASE 1.5 - Authentication (login owner/kasir)
3. FASE 2 - Service Management
4. FASE 3 - Order Management (core feature)
5. FASE 4 - Customer Management
6. FASE 7 - Reports & Dashboard (dengan export/share)
7. FASE 8 - Settings & Polish
8. FASE 5 & 6 - Printer & WhatsApp (nice to have)
9. FASE 9 - Final testing & demo

### Key Decisions
- **Workflow**: Flexible (bisa skip Ready atau tidak)
- **Currency**: Rupiah tanpa decimal
- **Invoice Format**: LNDR-YYMMDD-NNNN (reset daily)
- **Printer**: 58mm thermal (32 chars width)
- **Auth**: Simple username/password, role-based (owner/kasir)
- **Customer**: Auto-create dari order, bisa export & broadcast WA
- **Report Export**: Excel & CSV, share via WA

### Role Permissions Summary
| Feature | Owner | Kasir |
|---------|-------|-------|
| Dashboard | Full | View only |
| Orders | Full CRUD | Create, View, Update |
| Services | Full CRUD | View only |
| Customers | Full + Export | View only |
| Reports | Full + Export | No access |
| Settings | Full | No access |
| User Management | Full | No access |

### Common Pitfalls to Avoid
- Invoice number duplicate → use UNIQUE constraint + check last number
- App crash saat print → wrap with try-catch
- WA tidak terbuka → validate phone format
- Layout overflow → use SingleChildScrollView
- Slow query → add proper indexes
- Password storage → always hash, never plaintext
- Session expired → check on app resume
- Export large data → use pagination/streaming
