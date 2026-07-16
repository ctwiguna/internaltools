# Skenario Demo: Offline-First dengan Supabase Sync

## Persiapan Sebelum Demo

### 1. Setup Device
- Siapkan 2 device (bisa emulator + physical atau 2 physical device)
- Pastikan akun Supabase sudah dibuat sebelumnya
- Login dengan akun yang sama di kedua device

### 2. Data Awal
- Pastikan sudah ada beberapa data sample di local (customers, services, orders)
- Atau siapkan untuk input data baru saat demo

---

## Skenario Demo

### PART 1: Menunjukkan Mode Offline (3-5 menit)

#### Step 1.1: Tunjukkan Status Offline
1. **Matikan WiFi/Data** pada device
2. Buka app dan tunjukkan:
   - Badge **"Offline"** di header Dashboard (abu-abu)
   - Card **"Mode Offline"** berwarna abu-abu
   - Pesan: "Tidak ada koneksi internet"

#### Step 1.2: Buat Order Saat Offline
1. Tap **"Order Baru"** di Menu Cepat
2. Pilih atau buat customer baru
3. Pilih layanan dan quantity
4. Simpan order
5. **Highlight**: Order berhasil disimpan ke database lokal (SQLite)

#### Step 1.3: Buat Data Lainnya
1. Tambah customer baru
2. Tambah/edit layanan
3. Semua tersimpan di lokal

**Narasi**:
> "Seperti yang Anda lihat, aplikasi tetap berfungsi 100% meskipun tidak ada koneksi internet. Semua data tersimpan di SQLite lokal."

---

### PART 2: Aktivasi Mode Online (5-7 menit)

#### Step 2.1: Nyalakan Internet
1. **Nyalakan WiFi/Data**
2. Lihat perubahan di Dashboard:
   - Badge berubah dari "Offline" ke "Online" (hijau)
   - Jika belum login, Card masih abu-abu dengan pesan "Login untuk mengaktifkan sync"

#### Step 2.2: Login ke Supabase
1. Tap **Card "Mode Offline"** atau menu **"Cloud"**
2. Masuk ke halaman **Mode Online**
3. Tunjukkan form Login/Daftar
4. **Login** dengan email dan password

#### Step 2.3: Tunjukkan Mode Online Aktif
1. Setelah login, kembali ke Dashboard
2. Tunjukkan:
   - Badge **"Online"** (hijau) di header
   - Card **"Mode Online"** dengan gradient hijau
   - Pesan: "Data tersinkronisasi dengan cloud"

**Narasi**:
> "Sekarang app dalam mode online. Setiap perubahan data akan otomatis tersinkronisasi ke cloud Supabase."

---

### PART 3: Demo Auto-Sync (5-7 menit)

#### Step 3.1: Buat Order Baru (Online)
1. Buat order baru saat online
2. Tunjukkan:
   - Badge berubah ke **"Sync"** dengan loading indicator
   - Card menunjukkan "Sedang menyinkronkan data..."
3. Setelah selesai:
   - Badge kembali ke "Online"
   - "Sync terakhir: Baru saja"

#### Step 3.2: Verifikasi di Supabase Dashboard (Optional)
1. Buka Supabase Dashboard di browser
2. Tunjukkan tabel `orders`, `customers`, dll
3. Data yang baru dibuat sudah ada di cloud

**Narasi**:
> "Order langsung tersinkronisasi ke cloud. Anda bisa lihat di Supabase Dashboard bahwa data sudah tersimpan di server."

---

### PART 4: Demo Offline → Online Sync (7-10 menit) ⭐ HIGHLIGHT

#### Step 4.1: Matikan Internet Lagi
1. **Matikan WiFi/Data**
2. Badge berubah ke "Offline"

#### Step 4.2: Buat Beberapa Transaksi Offline
1. Buat 2-3 order baru
2. Tambah 1 customer baru
3. Update status order yang ada

#### Step 4.3: Nyalakan Internet - MAGIC MOMENT!
1. **Nyalakan WiFi/Data**
2. **TUNJUKKAN**:
   - Badge langsung berubah ke **"Sync"** dengan animasi
   - Card menunjukkan "Sedang menyinkronkan data..."
   - Jika ada pending, tampil badge orange "X pending"
3. Setelah sync selesai:
   - Badge "Online"
   - "Sync terakhir: Baru saja"

**Narasi**:
> "INI adalah fitur utama! Saat koneksi kembali, semua data yang dibuat offline OTOMATIS tersinkronisasi ke cloud. User tidak perlu melakukan apapun."

---

### PART 5: Demo Multi-Device Sync (5-7 menit) ⭐ PREMIUM FEATURE

#### Step 5.1: Setup Device Kedua
1. Buka app di device kedua
2. Login dengan akun yang sama

#### Step 5.2: Restore Data dari Cloud
1. Di device kedua, masuk ke **Mode Online**
2. Tap **"Restore Data dari Cloud"**
3. Konfirmasi restore
4. Tunjukkan data yang di-restore:
   - Customers
   - Services
   - Orders

#### Step 5.3: Verifikasi Data Sama
1. Bandingkan data di kedua device
2. Semua order, customer, layanan sama

**Narasi**:
> "Dengan fitur ini, Anda bisa punya multiple device atau kasir yang datanya selalu tersinkronisasi. Jika device rusak, data aman di cloud dan bisa di-restore kapanpun."

---

### PART 6: Demo Multi-Outlet (5-7 menit) ⭐ NEW FEATURE

#### Step 6.1: Tunjukkan Outlet Aktif di Dashboard
1. Buka Dashboard
2. **Highlight**: Nama outlet aktif ditampilkan di header, di bawah nama user
   - Icon store (🏪) + Nama Outlet
   - Contoh: "🏪 Outlet Palagan"

#### Step 6.2: Kelola Outlet
1. Masuk ke **Settings** > **Kelola Outlet**
2. Tunjukkan daftar outlet yang ada
3. **Demo buat outlet baru**:
   - Tap "Tambah Outlet"
   - Isi nama, alamat, telepon, prefix invoice
   - Simpan

#### Step 6.3: Switch Outlet
1. Di halaman Kelola Outlet, tap outlet lain
2. Pilih **"Gunakan Outlet Ini"**
3. Kembali ke Dashboard
4. **Tunjukkan**:
   - Nama outlet di header berubah
   - Data order/customer/layanan berubah sesuai outlet
   - Omzet dan statistik berubah sesuai outlet

#### Step 6.4: Tunjukkan Data Terpisah Per Outlet
1. Buat order di Outlet A
2. Switch ke Outlet B
3. **Tunjukkan**: Order dari Outlet A tidak muncul di Outlet B

**Narasi**:
> "Fitur Multi-Outlet memungkinkan Anda mengelola beberapa cabang laundry dalam satu aplikasi. Setiap outlet memiliki data terpisah - customers, layanan, dan orders. Anda bisa dengan mudah switch antar outlet tanpa perlu logout."

---

### PART 7: Demo Backup Manual (3-5 menit)

#### Step 7.1: Tunjukkan Fitur Backup
1. Masuk ke **Mode Online** settings
2. Tap **"Upload Data ke Cloud"**
3. Tunjukkan konfirmasi dengan jumlah data:
   - X pelanggan
   - X layanan
   - X pesanan

#### Step 7.2: Proses Backup
1. Tap "Sinkronisasi"
2. Tunjukkan loading indicator
3. Tunjukkan hasil backup sukses

**Narasi**:
> "Selain auto-sync, user juga bisa melakukan backup manual kapan saja untuk memastikan semua data sudah di-upload ke cloud."

---

## Flow Diagram untuk Demo

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEMO FLOW                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐          │
│  │ OFFLINE │ -> │ LOGIN   │ -> │ ONLINE  │ -> │ SYNC    │          │
│  │ MODE    │    │ SUPABASE│    │ MODE    │    │ DATA    │          │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘          │
│       │                             │              │                 │
│       v                             v              v                 │
│  ┌─────────┐                  ┌─────────┐    ┌─────────┐           │
│  │ CREATE  │                  │ AUTO    │    │ MULTI   │           │
│  │ ORDER   │                  │ SYNC    │    │ DEVICE  │           │
│  │ OFFLINE │                  │ ON      │    │ SYNC    │           │
│  └─────────┘                  │ CONNECT │    └─────────┘           │
│                               └─────────┘         │                 │
│                                                   v                 │
│                                             ┌─────────┐            │
│                                             │ MULTI   │            │
│                                             │ OUTLET  │ ⭐ NEW     │
│                                             │ SWITCH  │            │
│                                             └─────────┘            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Fitur Multi-Outlet - Detail Teknis

### Apa yang Dipisah Per Outlet:
- **Customers** - Pelanggan per outlet
- **Services** - Layanan dan harga per outlet
- **Orders** - Pesanan per outlet
- **Reports** - Laporan omzet per outlet

### Apa yang Dibagikan:
- **User Account** - Satu akun bisa akses semua outlet
- **Cloud Sync** - Semua outlet ter-sync ke cloud yang sama

### UI Multi-Outlet:
1. **Dashboard Header**: Menampilkan nama outlet aktif
2. **Settings > Kelola Outlet**: CRUD outlet
3. **Auto-filter**: Semua query data otomatis filter by outlet

---

## Tips untuk Recording Demo

### Visual yang Perlu Di-highlight:

1. **Badge Status** di header - perubahan warna dan text
2. **Cloud Sync Card** - gradient, animasi, pesan status
3. **Sync Animation** - loading indicator saat syncing
4. **Pending Count** - badge orange jika ada data pending
5. **Outlet Name** di header - menunjukkan outlet aktif ⭐ NEW
6. **Outlet Switch** - perubahan data saat ganti outlet ⭐ NEW

### Timing yang Bagus:

- Total durasi: 30-40 menit (tambah 5-7 menit untuk multi-outlet)
- Pause sebentar saat transisi status (offline → online)
- Zoom/highlight pada UI yang berubah
- Tunjukkan perubahan data saat switch outlet

### Checklist Sebelum Recording:

- [ ] WiFi/Data bisa di-toggle dengan mudah
- [ ] Akun Supabase sudah ready
- [ ] Data sample sudah ada
- [ ] Minimal 2 outlet sudah dibuat ⭐ NEW
- [ ] Data berbeda di masing-masing outlet ⭐ NEW
- [ ] Battery device cukup
- [ ] Screen recording sudah setup

---

## Troubleshooting

### Jika Sync Tidak Jalan:
1. Cek koneksi internet
2. Pastikan sudah login (authenticated)
3. Lihat status di "Status Sinkronisasi" bottom sheet

### Jika Data Tidak Muncul di Device Lain:
1. Pastikan login dengan akun yang sama
2. Lakukan "Restore Data dari Cloud"
3. Pull-to-refresh di Dashboard

### Jika Outlet Tidak Muncul di Header:
1. Pastikan minimal ada 1 outlet
2. Pull-to-refresh Dashboard
3. Cek Settings > Kelola Outlet

---

## Closing Statement untuk Demo

> "Fitur offline-first dengan Supabase sync ini membuat aplikasi laundry Anda:
> 1. **Reliable** - Tetap berfungsi tanpa internet
> 2. **Secure** - Data ter-backup di cloud
> 3. **Scalable** - Support multi-device DAN multi-outlet
> 4. **Seamless** - Auto-sync tanpa intervensi user
> 5. **Flexible** - Kelola banyak cabang dalam satu app ⭐ NEW
>
> Ini adalah fitur PREMIUM yang membedakan dengan versi free!"
