# Panduan Pengembangan Aplikasi Laundry JagoFlutter

Dokumentasi ini menjelaskan cara mengkustomisasi dan mengembangkan aplikasi Laundry JagoFlutter untuk kebutuhan bisnis Anda.

---

## Daftar Isi

1. [Fitur Aplikasi](#fitur-aplikasi)
2. [Tech Stack](#tech-stack)
3. [Struktur Project](#struktur-project)
4. [Mengganti Warna Tema](#mengganti-warna-tema)
5. [Mengganti Nama Aplikasi](#mengganti-nama-aplikasi)
6. [Mengganti Logo Aplikasi](#mengganti-logo-aplikasi)
7. [Mengganti Package Name](#mengganti-package-name)
8. [Mengganti Informasi Laundry Default](#mengganti-informasi-laundry-default)
9. [Menambah Fitur Baru](#menambah-fitur-baru)
10. [Arsitektur & State Management](#arsitektur--state-management)

---

## Fitur Aplikasi

### Fitur Utama

| Fitur | Deskripsi |
|-------|-----------|
| **Full Offline Mode** | Aplikasi berjalan 100% tanpa internet, data tersimpan lokal |
| **Manajemen Order** | Buat, edit, lihat detail, dan kelola status pesanan laundry |
| **Manajemen Pelanggan** | Database pelanggan lengkap dengan riwayat transaksi |
| **Paket Layanan** | Kelola berbagai jenis layanan (cuci kering, setrika, dll) |
| **Laporan Penjualan** | Analisa pendapatan harian, mingguan, bulanan dengan grafik |
| **Multi User** | Support role Owner dan Kasir dengan hak akses berbeda |
| **Cetak Struk** | Dukungan printer thermal Bluetooth 58mm/80mm |
| **Export Excel** | Export laporan penjualan ke format Excel (.xlsx) |
| **Share WhatsApp** | Kirim struk digital ke pelanggan via WhatsApp |

### Detail Fitur per Modul

#### 1. Dashboard
- Ringkasan pendapatan hari ini
- Jumlah order berdasarkan status
- Grafik pendapatan mingguan
- Daftar order terbaru (5 terakhir)

#### 2. Manajemen Order
- Buat order baru dengan multiple items
- Status order: Pending → Proses → Selesai → Diambil
- Pembayaran: Lunas / Belum Lunas / Sebagian
- Metode bayar: Cash / Transfer
- Estimasi tanggal selesai
- Cetak struk & share WhatsApp

#### 3. Manajemen Pelanggan
- CRUD data pelanggan
- Nama, nomor telepon, alamat
- Riwayat order per pelanggan
- Quick action: WhatsApp, telepon

#### 4. Paket Layanan
- CRUD paket layanan
- Nama layanan, harga, satuan (kg/pcs)
- Estimasi durasi pengerjaan
- Status aktif/nonaktif

#### 5. Laporan
- Filter berdasarkan periode (hari/minggu/bulan/custom)
- Total pendapatan & jumlah transaksi
- Grafik trend penjualan
- Export ke Excel

#### 6. Pengaturan
- Info laundry (nama, alamat, telepon)
- Prefix nomor invoice
- Manajemen user (Owner only)
- Koneksi printer Bluetooth

#### 7. Multi User & Role
| Role | Hak Akses |
|------|-----------|
| **Owner** | Semua fitur + manajemen user + laporan lengkap |
| **Kasir** | Order, pelanggan, layanan (tanpa akses user & laporan detail) |

---

## Tech Stack

### Core Framework

| Technology | Version | Deskripsi |
|------------|---------|-----------|
| **Flutter** | 3.10.1+ | Cross-platform UI Framework |
| **Dart** | 3.0.0+ | Programming Language |

### State Management

| Package | Version | Deskripsi |
|---------|---------|-----------|
| **flutter_bloc** | 9.1.1 | State Management (BLoC/Cubit Pattern) |
| **equatable** | 2.0.8 | Object Comparison untuk BLoC State |

### Database & Storage

| Package | Version | Deskripsi |
|---------|---------|-----------|
| **sqflite** | 2.4.2 | SQLite Local Database |
| **shared_preferences** | 2.5.4 | Key-Value Storage untuk Session |
| **path_provider** | 2.1.5 | Akses File System |
| **path** | 1.9.1 | Path manipulation |

### UI & Design

| Package | Version | Deskripsi |
|---------|---------|-----------|
| **google_fonts** | 7.0.2 | Custom Typography (Poppins) |
| **fl_chart** | 1.1.1 | Charts & Grafik Laporan |
| **cupertino_icons** | 1.0.8 | iOS-style icons |

### Printer & Export

| Package | Version | Deskripsi |
|---------|---------|-----------|
| **print_bluetooth_thermal** | 1.1.9 | Koneksi Printer Bluetooth |
| **esc_pos_utils_plus** | 2.0.3 | ESC/POS Commands untuk Printer |
| **excel** | 4.0.6 | Export Laporan ke Excel |

### Sharing & External

| Package | Version | Deskripsi |
|---------|---------|-----------|
| **share_plus** | 12.0.1 | Share ke WhatsApp & Apps lain |
| **url_launcher** | 6.3.2 | Buka URL External |
| **permission_handler** | 12.0.1 | Handle Permissions Android |

### Utilities

| Package | Version | Deskripsi |
|---------|---------|-----------|
| **intl** | 0.20.2 | Format Tanggal & Mata Uang |
| **uuid** | 4.5.2 | Generate Unique ID |
| **crypto** | 3.0.6 | Enkripsi Password (SHA-256) |

### Dev Dependencies

| Package | Version | Deskripsi |
|---------|---------|-----------|
| **flutter_launcher_icons** | 0.14.3 | Generate App Icons |
| **change_app_package_name** | 1.5.0 | Ubah Package Name |
| **flutter_lints** | 6.0.0 | Linting Rules |

---

## Struktur Project

```
lib/
├── core/                          # Core functionality
│   ├── constants/
│   │   ├── app_constants.dart     # Konstanta aplikasi (nama, versi, dll)
│   │   └── colors.dart            # Definisi warna (legacy)
│   ├── exceptions/
│   │   └── database_exception.dart # Custom exceptions
│   ├── services/
│   │   ├── export_service.dart    # Export ke Excel
│   │   ├── laundry_print.dart     # Format struk untuk printer
│   │   ├── printer_service.dart   # Koneksi printer Bluetooth
│   │   ├── session_service.dart   # Manajemen session user
│   │   └── whatsapp_service.dart  # Kirim struk via WhatsApp
│   ├── theme/
│   │   └── app_theme.dart         # Design system (warna, typography, spacing)
│   └── utils/
│       ├── currency_formatter.dart     # Format mata uang
│       ├── date_formatter.dart         # Format tanggal
│       ├── invoice_generator.dart      # Generate nomor invoice
│       ├── password_helper.dart        # Enkripsi password
│       └── thousand_separator_formatter.dart # Format ribuan
│
├── data/                          # Data layer
│   ├── database/
│   │   └── database_helper.dart   # SQLite database helper & migrations
│   ├── models/
│   │   ├── app_setting.dart       # Model pengaturan
│   │   ├── customer.dart          # Model pelanggan
│   │   ├── order.dart             # Model order
│   │   ├── order_item.dart        # Model item order
│   │   ├── payment.dart           # Model pembayaran
│   │   ├── service.dart           # Model layanan
│   │   └── user.dart              # Model user
│   └── repositories/
│       ├── auth_repository.dart   # Repository autentikasi
│       ├── customer_repository.dart # Repository pelanggan
│       ├── order_repository.dart  # Repository order
│       ├── payment_repository.dart # Repository pembayaran
│       ├── report_repository.dart # Repository laporan
│       ├── service_repository.dart # Repository layanan
│       ├── settings_repository.dart # Repository pengaturan
│       └── user_repository.dart   # Repository user
│
├── logic/                         # Business logic layer
│   └── cubits/
│       ├── auth/
│       │   ├── auth_cubit.dart    # Logic autentikasi
│       │   └── auth_state.dart    # State autentikasi
│       ├── customer/
│       │   ├── customer_cubit.dart
│       │   └── customer_state.dart
│       ├── dashboard/
│       │   ├── dashboard_cubit.dart
│       │   └── dashboard_state.dart
│       ├── order/
│       │   ├── order_cubit.dart
│       │   └── order_state.dart
│       ├── printer/
│       │   ├── printer_cubit.dart
│       │   └── printer_state.dart
│       ├── report/
│       │   ├── report_cubit.dart
│       │   └── report_state.dart
│       ├── service/
│       │   ├── service_cubit.dart
│       │   └── service_state.dart
│       ├── settings/
│       │   ├── settings_cubit.dart
│       │   └── settings_state.dart
│       └── user/
│           ├── user_cubit.dart
│           └── user_state.dart
│
├── presentation/                  # UI layer
│   ├── screens/
│   │   ├── auth/
│   │   │   └── login_screen.dart
│   │   ├── customers/
│   │   │   ├── customer_detail_screen.dart
│   │   │   ├── customer_form_screen.dart
│   │   │   └── customer_list_screen.dart
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart
│   │   ├── orders/
│   │   │   ├── order_detail_screen.dart
│   │   │   ├── order_form_screen.dart
│   │   │   └── order_list_screen.dart
│   │   ├── reports/
│   │   │   └── report_screen.dart
│   │   ├── services/
│   │   │   ├── service_form_screen.dart
│   │   │   └── service_list_screen.dart
│   │   ├── settings/
│   │   │   ├── printer_settings_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   ├── user_form_screen.dart
│   │   │   └── user_management_screen.dart
│   │   └── main_screen.dart       # Bottom navigation wrapper
│   └── widgets/
│       ├── custom_button.dart     # Reusable button
│       ├── custom_card.dart       # Reusable card
│       ├── custom_text_field.dart # Reusable text field
│       ├── order_card.dart        # Card untuk order
│       └── status_badge.dart      # Badge status order
│
└── main.dart                      # Entry point aplikasi
```

---

## Mengganti Warna Tema

Warna tema aplikasi didefinisikan di file `lib/core/theme/app_theme.dart`.

### Langkah 1: Buka file theme

```
lib/core/theme/app_theme.dart
```

### Langkah 2: Edit class `AppThemeColors`

```dart
class AppThemeColors {
  AppThemeColors._();

  // Primary Purple Palette - GANTI WARNA DI SINI
  static const Color primary = Color(0xFF7B2D8E);        // Warna utama
  static const Color primaryLight = Color(0xFF9B4DB0);   // Warna utama terang
  static const Color primaryDark = Color(0xFF5A1D6B);    // Warna utama gelap
  static const Color primarySurface = Color(0xFFF3E5F5); // Background primary

  // Secondary Colors
  static const Color secondary = Color(0xFFE1BEE7);
  static const Color secondaryLight = Color(0xFFF8E8FC);

  // Background Colors
  static const Color background = Color(0xFFFAF7FB);     // Background utama
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B7B);
  static const Color textHint = Color(0xFF9E9E9E);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);        // Hijau - sukses
  static const Color warning = Color(0xFFFF9800);        // Orange - warning
  static const Color error = Color(0xFFF44336);          // Merah - error
  static const Color info = Color(0xFF2196F3);           // Biru - info
}
```

### Contoh: Mengubah ke Tema Biru

```dart
// Primary Blue Palette
static const Color primary = Color(0xFF1976D2);        // Biru
static const Color primaryLight = Color(0xFF42A5F5);   // Biru terang
static const Color primaryDark = Color(0xFF0D47A1);    // Biru gelap
static const Color primarySurface = Color(0xFFE3F2FD); // Background biru

// Secondary Colors
static const Color secondary = Color(0xFFBBDEFB);
static const Color secondaryLight = Color(0xFFE1F5FE);

// Background - sesuaikan dengan tema
static const Color background = Color(0xFFF5F9FF);
```

### Contoh: Mengubah ke Tema Hijau

```dart
// Primary Green Palette
static const Color primary = Color(0xFF388E3C);        // Hijau
static const Color primaryLight = Color(0xFF66BB6A);   // Hijau terang
static const Color primaryDark = Color(0xFF1B5E20);    // Hijau gelap
static const Color primarySurface = Color(0xFFE8F5E9); // Background hijau

// Secondary Colors
static const Color secondary = Color(0xFFC8E6C9);
static const Color secondaryLight = Color(0xFFE8F5E9);

// Background
static const Color background = Color(0xFFF5FFF5);
```

### Langkah 3: Update Gradient (opsional)

```dart
// Di class AppThemeColors
static const LinearGradient primaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [primaryLight, primary],  // Sesuaikan dengan warna baru
);

static const LinearGradient headerGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [primaryLight, primary],
);
```

### Tools untuk Memilih Warna

- [Material Design Color Tool](https://material.io/resources/color/)
- [Coolors](https://coolors.co/)
- [Adobe Color](https://color.adobe.com/)

---

## Mengganti Nama Aplikasi

### 1. Nama Internal (Dart)

Edit file `lib/core/constants/app_constants.dart`:

```dart
class AppConstants {
  // App Info - GANTI DI SINI
  static const String appName = 'Laundry Anda';  // Nama aplikasi
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Deskripsi aplikasi Anda';

  // Default Laundry Info
  static const String defaultLaundryName = 'Nama Laundry Anda';
  static const String defaultLaundryAddress = 'Alamat Laundry Anda';
  static const String defaultLaundryPhone = '628xxxxxxxxxx';
}
```

### 2. Nama Android

Edit file `android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:label="Nama Aplikasi Anda"   <!-- GANTI DI SINI -->
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
```

### 3. Rebuild Aplikasi

Setelah mengubah nama, jalankan:

```bash
flutter clean
flutter pub get
flutter run
```

---

## Mengganti Logo Aplikasi

### Langkah 1: Siapkan File Logo

Siapkan file logo dengan spesifikasi:
- Format: **PNG** (dengan transparansi)
- Ukuran minimum: **1024x1024 pixel**
- Bentuk: **Persegi** (1:1 ratio)

### Langkah 2: Replace File Logo

Ganti file logo di:
```
assets/icons/logolaundry.png
```

### Langkah 3: Update pubspec.yaml (jika nama file berbeda)

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icons/logo_baru.png"  # Path ke logo baru
  adaptive_icon_background: "#FFFFFF"        # Background untuk Android adaptive icon
  adaptive_icon_foreground: "assets/icons/logo_baru.png"
```

### Langkah 4: Generate Icon

```bash
flutter pub run flutter_launcher_icons
```

### Langkah 5: Verify

Icon akan digenerate ke folder:
```
android/app/src/main/res/mipmap-hdpi/
android/app/src/main/res/mipmap-mdpi/
android/app/src/main/res/mipmap-xhdpi/
android/app/src/main/res/mipmap-xxhdpi/
android/app/src/main/res/mipmap-xxxhdpi/
```

### Tips untuk Logo yang Bagus

1. **Gunakan padding** - Beri ruang 10-15% dari tepi
2. **Hindari teks kecil** - Logo harus terlihat jelas di ukuran kecil
3. **Test di berbagai background** - Pastikan logo terlihat di light/dark mode
4. **Gunakan warna solid** - Hindari gradien kompleks untuk icon kecil

---

## Mengganti Package Name

Package name adalah identifier unik aplikasi di Play Store.

### Langkah 1: Jalankan Command

```bash
flutter pub run change_app_package_name:main com.namaanda.namaaplikasi
```

Contoh:
```bash
flutter pub run change_app_package_name:main com.mycompany.laundryapp
```

### Langkah 2: Verify Perubahan

Command di atas akan mengubah file-file berikut:

| File | Yang Diubah |
|------|-------------|
| `android/app/build.gradle.kts` | `applicationId` |
| `android/app/build.gradle.kts` | `namespace` |
| `android/app/src/main/kotlin/...` | Folder struktur package |
| `android/app/src/main/AndroidManifest.xml` | Package reference |

### Langkah 3: Clean & Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

### Format Package Name

Format: `com.company.appname`

Contoh: `com.jagoflutter.laundryoffline`

**Aturan:**
- Hanya huruf kecil, angka, dan titik
- Tidak boleh diawali angka
- Minimal 2 segmen (com.app)
- Tidak boleh menggunakan kata reserved (java, android, dll)

---

## Mengganti Informasi Laundry Default

### Langkah 1: Edit App Constants

File: `lib/core/constants/app_constants.dart`

```dart
class AppConstants {
  // ... kode lain ...

  // Default Laundry Info - GANTI DI SINI
  static const String defaultLaundryName = 'Laundry Bersih Wangi';
  static const String defaultLaundryAddress = 'Jl. Sudirman No. 123, Jakarta';
  static const String defaultLaundryPhone = '6281234567890';

  // Invoice
  static const String defaultInvoicePrefix = 'LBW';  // Prefix nomor invoice

  // Default Admin Credentials
  static const String defaultOwnerUsername = 'admin';
  static const String defaultOwnerPassword = 'password123';
  static const String defaultOwnerName = 'Administrator';
}
```

### Langkah 2: Reset Database (untuk testing)

Jika sudah pernah menjalankan aplikasi sebelumnya, hapus app data atau reinstall untuk melihat perubahan default.

**Cara hapus app data di Android:**
1. Settings > Apps > Laundry App
2. Storage > Clear Data

Atau uninstall dan install ulang aplikasi.

---

## Menambah Fitur Baru

### Contoh: Menambah Model Baru

**1. Buat Model** di `lib/data/models/promo.dart`:

```dart
class Promo {
  final int? id;
  final String name;
  final double discountPercent;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  Promo({
    this.id,
    required this.name,
    required this.discountPercent,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'discount_percent': discountPercent,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Promo.fromMap(Map<String, dynamic> map) {
    return Promo(
      id: map['id'],
      name: map['name'],
      discountPercent: map['discount_percent'],
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      isActive: map['is_active'] == 1,
    );
  }
}
```

**2. Update Database** di `lib/data/database/database_helper.dart`:

```dart
// Tambah tabel baru di method _onCreate
await db.execute('''
  CREATE TABLE promos(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    discount_percent REAL NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    is_active INTEGER DEFAULT 1
  )
''');

// Jika database sudah ada, buat migration
// Increment databaseVersion di app_constants.dart
// Tambah migration di _onUpgrade
```

**3. Buat Repository** di `lib/data/repositories/promo_repository.dart`:

```dart
class PromoRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<Promo>> getAll() async {
    final db = await _db.database;
    final result = await db.query('promos');
    return result.map((e) => Promo.fromMap(e)).toList();
  }

  Future<int> create(Promo promo) async {
    final db = await _db.database;
    return await db.insert('promos', promo.toMap());
  }

  // ... CRUD methods lainnya
}
```

**4. Buat Cubit** di `lib/logic/cubits/promo/`:

```dart
// promo_state.dart
abstract class PromoState {}
class PromoInitial extends PromoState {}
class PromoLoading extends PromoState {}
class PromoLoaded extends PromoState {
  final List<Promo> promos;
  PromoLoaded(this.promos);
}
class PromoError extends PromoState {
  final String message;
  PromoError(this.message);
}

// promo_cubit.dart
class PromoCubit extends Cubit<PromoState> {
  final PromoRepository _repository;

  PromoCubit(this._repository) : super(PromoInitial());

  Future<void> loadPromos() async {
    emit(PromoLoading());
    try {
      final promos = await _repository.getAll();
      emit(PromoLoaded(promos));
    } catch (e) {
      emit(PromoError(e.toString()));
    }
  }
}
```

**5. Buat Screen** di `lib/presentation/screens/promos/`:

```dart
// promo_list_screen.dart
class PromoListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PromoCubit, PromoState>(
      builder: (context, state) {
        if (state is PromoLoading) {
          return CircularProgressIndicator();
        }
        if (state is PromoLoaded) {
          return ListView.builder(
            itemCount: state.promos.length,
            itemBuilder: (context, index) {
              return PromoCard(promo: state.promos[index]);
            },
          );
        }
        return Container();
      },
    );
  }
}
```

---

## Arsitektur & State Management

### Arsitektur: Clean Architecture (Simplified)

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Screens   │  │   Widgets   │  │   BLoC/Cubit        │  │
│  │  (UI Pages) │  │ (Reusable)  │  │ (State Management)  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                      DOMAIN LAYER                            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                   Repositories                           ││
│  │  (Abstract business logic, data transformation)          ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│                       DATA LAYER                             │
│  ┌─────────────────┐  ┌─────────────────────────────────┐   │
│  │     Models      │  │         Database Helper         │   │
│  │  (Data classes) │  │  (SQLite CRUD operations)       │   │
│  └─────────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### State Management: BLoC/Cubit

**Cubit** digunakan untuk state management yang lebih simple (tanpa events):

```dart
// State
abstract class OrderState {}
class OrderLoading extends OrderState {}
class OrderLoaded extends OrderState {
  final List<Order> orders;
  OrderLoaded(this.orders);
}

// Cubit
class OrderCubit extends Cubit<OrderState> {
  OrderCubit() : super(OrderInitial());

  void loadOrders() async {
    emit(OrderLoading());
    final orders = await repository.getAll();
    emit(OrderLoaded(orders));
  }
}

// Usage in Widget
BlocBuilder<OrderCubit, OrderState>(
  builder: (context, state) {
    if (state is OrderLoaded) {
      return ListView(children: state.orders.map(...));
    }
    return CircularProgressIndicator();
  },
)
```

### Flow Data

```
User Action → Screen → Cubit → Repository → Database
                ↑                              │
                └──────────── State ←──────────┘
```

1. **User** melakukan aksi (tap button, submit form)
2. **Screen** memanggil method di **Cubit**
3. **Cubit** memanggil **Repository** untuk operasi data
4. **Repository** melakukan query ke **Database**
5. Data dikembalikan dan **Cubit** emit state baru
6. **Screen** rebuild dengan state baru

---

## Tips Pengembangan

### 1. Hot Reload vs Hot Restart

- **Hot Reload** (r): Untuk perubahan UI, tidak reset state
- **Hot Restart** (R): Untuk perubahan logic, reset state
- **Full Restart**: Untuk perubahan native (package name, icon, permissions)

### 2. Debug Mode

```dart
// Di main.dart atau dimana saja
if (kDebugMode) {
  print('Debug info: $data');
}
```

### 3. Database Migration

Saat mengubah struktur database:

1. Increment version di `app_constants.dart`:
   ```dart
   static const int databaseVersion = 3; // dari 2 ke 3
   ```

2. Tambah migration di `database_helper.dart`:
   ```dart
   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
     if (oldVersion < 3) {
       await db.execute('ALTER TABLE orders ADD COLUMN notes TEXT');
     }
   }
   ```

### 4. Testing di Device Android

```bash
# List device yang terkoneksi
flutter devices

# Run di device terkoneksi
flutter run

# Run di device spesifik
flutter run -d <device_id>

# Run mode
flutter run --debug               # Debug mode (default)
flutter run --profile             # Profile mode (untuk performance testing)
flutter run --release             # Release mode (untuk testing final)
```

### 5. Build APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Split per ABI (ukuran lebih kecil)
flutter build apk --release --split-per-abi

# App Bundle untuk Play Store
flutter build appbundle --release
```

Output APK:
```
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (jika split)
```

---

## Referensi

- [Flutter Documentation](https://docs.flutter.dev/)
- [BLoC Pattern](https://bloclibrary.dev/)
- [Material Design](https://material.io/design)
- [SQLite Flutter](https://pub.dev/packages/sqflite)

---

<p align="center">
  <strong>Happy Coding!</strong><br/>
  Made with love by <a href="https://jagoflutter.com">JagoFlutter.com</a>
</p>
