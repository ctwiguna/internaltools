# Zenn Laundry — Laundry POS (Internal Tools)

## Tujuan Repositori Ini

Repositori ini menyimpan kode sumber lengkap untuk **Zenn Laundry**, aplikasi Point-of-Sale (POS) khusus usaha laundry skala UMKM di Indonesia. Aplikasi ini dirancang dengan paradigma **offline-first**, artinya seluruh operasional kasir dapat berjalan 100% tanpa koneksi internet, dengan sinkronisasi cloud sebagai fitur opsional untuk backup dan multi-perangkat.

---

## Apa yang Dibangun

Sebuah aplikasi cross-platform (Android, iOS, Web) berbasis **Flutter** yang berfungsi sebagai sistem kasir end-to-end untuk bisnis laundry, mencakup:

- Pencatatan pesanan laundry dengan status tracking
- Manajemen data pelanggan dan layanan (kilat, reguler, dll.)
- Multi-outlet / multi-cabang dalam satu aplikasi
- Pembayaran multi-metode (tunai, transfer, QRIS)
- Pencetakan struk via printer thermal Bluetooth
- Laporan penjualan harian, mingguan, bulanan dengan grafik
- Export data ke Excel dan share struk via WhatsApp
- Peran pengguna: Owner (akses penuh) dan Kasir (terbatas per outlet)

---

## Arsitektur Teknologi

| Layer | Teknologi |
|-------|-----------|
| **Framework UI** | Flutter 3.10+, Dart 3.0+ |
| **State Management** | flutter_bloc (BLoC / Cubit Pattern) |
| **Database Lokal** | sqflite (SQLite) |
| **Database Cloud** | Supabase (PostgreSQL + Auth) |
| **Local Storage** | shared_preferences (session, onboarding) |
| **Sync & Connectivity** | connectivity_plus, custom SyncService dengan offline queue |
| **Printing** | print_bluetooth_thermal + esc_pos_utils_plus |
| **Export & Share** | excel, share_plus, url_launcher |
| **Charts** | fl_chart |
| **Dependency Injection** | Service Locator (singleton services) |

---

## Struktur Direktori Utama

```
lib/
├── core/                    # Konstanta, theme, utility, services
│   ├── constants/
│   ├── services/            # Connectivity, Sync, Supabase, Printer, Outlet, Restore
│   ├── theme/               # Design system (warna, typography, shadow)
│   └── utils/               # Formatter, validator, helper
├── data/                    # Database, models, repositories
│   ├── database/            # SQLite helper & migrations
│   ├── models/              # Entity: Order, Customer, Service, Outlet, Payment, User
│   └── repositories/        # Local repo, Supabase repo, Hybrid repo, Syncable repo
├── logic/                   # Business logic / state management
│   └── cubits/              # Auth, Order, Customer, Service, Outlet, Report, Sync, Dashboard
├── presentation/            # UI Layer
│   ├── screens/             # Login, Dashboard, Orders, Customers, Services, Reports, Settings
│   └── widgets/             # Reusable UI components
└── main.dart                # Entry point & service initialization
```

---

## Alur Data & Sinkronisasi

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   User UI   │────▶│   Cubits    │────▶│ Repositories│
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                         ┌─────────────────────┼─────────────────────┐
                         │                     │                     │
                         ▼                     ▼                     ▼
                  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
                  │   SQLite    │      │  Supabase   │      │  Sync Queue │
                  │   (Local)   │◀────▶│   (Cloud)   │      │  (Offline)  │
                  └─────────────┘      └─────────────┘      └─────────────┘
```

- **Online**: Data langsung disimpan ke SQLite dan di-sync otomatis ke Supabase.
- **Offline**: Data disimpan ke SQLite dan masuk ke *sync queue*. Begitu online, queue diproses secara otomatis.
- **Multi-device**: Login dengan akun yang sama di perangkat lain, lalu *Restore Data dari Cloud* untuk menarik seluruh data.

---

## Konfigurasi Singkat

1. **Prerequisites**: Flutter SDK >= 3.10.1, Dart >= 3.0.0, Java 17.
2. **Clone & Install**:
   ```bash
   flutter pub get
   ```
3. **Environment** (opsional, untuk cloud sync):
   ```bash
   cp .env.example .env
   # Isi SUPABASE_URL dan SUPABASE_ANON_KEY
   ```
4. **Build APK**:
   ```bash
   flutter build apk --release
   ```

---

## Catatan Penting

- Aplikasi **dapat berjalan sepenuhnya tanpa Supabase**. Fitur cloud adalah opsional premium.
- Semua data sensitif (password) dienkripsi menggunakan `crypto` sebelum disimpan.
- Setiap outlet memiliki isolasi data mandiri: pelanggan, layanan, dan pesanan terpisah per cabang.
- Project ini menggunakan konvensi nama package: `com.zennlaundry.pos`.

---

*Dokumen ini dibuat untuk memberikan gambaran teknis singkat bagi AI assistant atau developer baru yang masuk ke repositori ini.*
