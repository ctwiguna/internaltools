# Analisis & Rencana Integrasi Supabase

Dokumen ini berisi analisis arsitektur saat ini dan rencana pengembangan untuk mengintegrasikan Supabase agar aplikasi bisa berjalan online dengan sync data ke cloud.

---

## Daftar Isi

1. [Tujuan Integrasi](#tujuan-integrasi)
2. [Arsitektur Saat Ini](#arsitektur-saat-ini)
3. [Tantangan Migrasi](#tantangan-migrasi)
4. [Strategi Integrasi](#strategi-integrasi)
5. [Skema Database Supabase](#skema-database-supabase)
6. [Rencana Implementasi](#rencana-implementasi)
7. [Estimasi Dependencies](#estimasi-dependencies)

---

## Tujuan Integrasi

### Mengapa Supabase?

| Fitur | Manfaat |
|-------|---------|
| **Authentication** | Login dengan email, social auth, magic link |
| **PostgreSQL Database** | Database relasional yang powerful |
| **Realtime** | Sync data antar device secara real-time |
| **Row Level Security** | Keamanan data per user/laundry |
| **Storage** | Simpan gambar/file (struk, foto order) |
| **Edge Functions** | Logic di server (notifikasi, scheduled jobs) |
| **Free Tier** | Gratis untuk UMKM skala kecil |

### Target Setelah Integrasi

1. **Multi-device sync** - Data tersinkron di semua device
2. **Multi-outlet support** - Satu owner bisa kelola banyak outlet
3. **Backup otomatis** - Data aman di cloud
4. **Akses dari mana saja** - Tidak terikat satu device
5. **Tetap offline-capable** - Bisa jalan tanpa internet (hybrid)

---

## Arsitektur Saat Ini

### Database Schema (SQLite)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   USERS     │     │  SERVICES   │     │  CUSTOMERS  │
├─────────────┤     ├─────────────┤     ├─────────────┤
│ id (PK)     │     │ id (PK)     │     │ id (PK)     │
│ username    │     │ name        │     │ name        │
│ password    │     │ unit        │     │ phone       │
│ name        │     │ price       │     │ address     │
│ role        │     │ duration    │     │ total_orders│
│ is_active   │     │ is_active   │     │ total_spent │
└─────────────┘     └─────────────┘     └─────────────┘
                           │                   │
                           ▼                   ▼
                    ┌─────────────┐     ┌─────────────┐
                    │ORDER_ITEMS  │◄────│   ORDERS    │
                    ├─────────────┤     ├─────────────┤
                    │ id (PK)     │     │ id (PK)     │
                    │ order_id(FK)│     │ invoice_no  │
                    │ service_id  │     │ customer_id │
                    │ service_name│     │ status      │
                    │ quantity    │     │ total_price │
                    │ subtotal    │     │ paid        │
                    └─────────────┘     │ created_by  │
                                        └──────┬──────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  PAYMENTS   │
                                        ├─────────────┤
                                        │ id (PK)     │
                                        │ order_id(FK)│
                                        │ amount      │
                                        │ method      │
                                        │ received_by │
                                        └─────────────┘
```

### Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                     │
│                 (Screens, Widgets)                       │
├─────────────────────────────────────────────────────────┤
│                   LOGIC LAYER                            │
│              (BLoC/Cubit - State Management)             │
├─────────────────────────────────────────────────────────┤
│                   DATA LAYER                             │
│    ┌─────────────────────────────────────────────┐      │
│    │              REPOSITORIES                    │      │
│    │  (AuthRepo, OrderRepo, CustomerRepo, etc)   │      │
│    └─────────────────────────────────────────────┘      │
│                         │                                │
│                         ▼                                │
│    ┌─────────────────────────────────────────────┐      │
│    │            DATABASE HELPER                   │      │
│    │               (SQLite)                       │      │
│    └─────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

### Repositories yang Ada

| Repository | Fungsi |
|------------|--------|
| `AuthRepository` | Login, logout, session management |
| `UserRepository` | CRUD users, role management |
| `CustomerRepository` | CRUD customers, statistics |
| `ServiceRepository` | CRUD layanan laundry |
| `OrderRepository` | CRUD orders, status management |
| `PaymentRepository` | CRUD payments, revenue tracking |
| `ReportRepository` | Aggregasi data laporan |
| `SettingsRepository` | Key-value settings |

---

## Tantangan Migrasi

### 1. ID Management

| Saat Ini | Supabase |
|----------|----------|
| Auto-increment INTEGER | UUID (string) |
| `id: 1, 2, 3...` | `id: 'a1b2c3d4-...'` |

**Solusi:** Gunakan UUID di semua model, tambah field `local_id` untuk backward compatibility.

### 2. Authentication

| Saat Ini | Supabase |
|----------|----------|
| Username + Password hash | Email + Supabase Auth |
| Session di SharedPreferences | Supabase Session Token |
| Role di tabel users | Role di user metadata + RLS |

**Solusi:** Migrasi ke Supabase Auth, simpan role di `user_metadata`.

### 3. Offline Support

| Saat Ini | Supabase |
|----------|----------|
| Full offline (SQLite only) | Perlu sync mechanism |
| Instant save | Perlu queue untuk offline mutations |

**Solusi:** Hybrid approach - SQLite untuk cache lokal + sync ke Supabase.

### 4. Data Denormalization

Saat ini `customer_name` disimpan di `orders` untuk offline support. Perlu dipertahankan untuk performa.

### 5. Multi-tenant (Multi Outlet)

Perlu tambah konsep `outlet_id` untuk mendukung banyak outlet dalam satu akun.

---

## Strategi Integrasi

### Pendekatan: Hybrid Offline-First

```
┌─────────────────────────────────────────────────────────┐
│                     FLUTTER APP                          │
├─────────────────────────────────────────────────────────┤
│                   LOGIC LAYER                            │
│                  (BLoC/Cubit)                            │
├─────────────────────────────────────────────────────────┤
│                 REPOSITORY LAYER                         │
│    ┌─────────────────────────────────────────────┐      │
│    │           SYNC REPOSITORY                    │      │
│    │  (Koordinator antara Local & Remote)        │      │
│    └─────────────────────────────────────────────┘      │
│              │                       │                   │
│              ▼                       ▼                   │
│    ┌─────────────────┐     ┌─────────────────┐         │
│    │ LOCAL DATASOURCE│     │REMOTE DATASOURCE│         │
│    │    (SQLite)     │     │   (Supabase)    │         │
│    └─────────────────┘     └─────────────────┘         │
└─────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                            ┌─────────────────┐
                            │    SUPABASE     │
                            │   PostgreSQL    │
                            │   + Auth        │
                            │   + Realtime    │
                            └─────────────────┘
```

### Sync Strategy

```
WRITE (Create/Update/Delete):
1. Simpan ke SQLite (immediate)
2. Tambah ke sync_queue
3. Jika online → sync ke Supabase
4. Jika offline → akan sync saat online

READ:
1. Baca dari SQLite (fast)
2. Background: check Supabase untuk updates
3. Jika ada perubahan → update SQLite → notify UI

CONFLICT RESOLUTION:
- Last-write-wins dengan timestamp
- Atau: server-wins untuk data critical
```

---

## Skema Database Supabase

### Tabel Utama

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- OUTLETS (untuk multi-outlet support)
CREATE TABLE outlets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  owner_id UUID REFERENCES auth.users(id),
  invoice_prefix TEXT DEFAULT 'INV',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- USERS (extends Supabase auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  outlet_id UUID REFERENCES outlets(id),
  name TEXT NOT NULL,
  role TEXT CHECK (role IN ('owner', 'kasir')) DEFAULT 'kasir',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- CUSTOMERS
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  notes TEXT,
  total_orders INTEGER DEFAULT 0,
  total_spent BIGINT DEFAULT 0,
  last_order_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(outlet_id, phone)
);

-- SERVICES
CREATE TABLE services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) NOT NULL,
  name TEXT NOT NULL,
  unit TEXT CHECK (unit IN ('kg', 'pcs')) DEFAULT 'kg',
  price BIGINT NOT NULL,
  duration_days INTEGER DEFAULT 3,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ORDERS
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) NOT NULL,
  invoice_no TEXT NOT NULL,
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  order_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  due_date TIMESTAMPTZ,
  status TEXT CHECK (status IN ('pending', 'process', 'ready', 'done')) DEFAULT 'pending',
  total_items INTEGER DEFAULT 0,
  total_weight DECIMAL(10,2) DEFAULT 0,
  total_price BIGINT NOT NULL,
  paid BIGINT DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(outlet_id, invoice_no)
);

-- ORDER_ITEMS
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  service_id UUID REFERENCES services(id) ON DELETE SET NULL,
  service_name TEXT NOT NULL,
  quantity DECIMAL(10,2) NOT NULL,
  unit TEXT NOT NULL,
  price_per_unit BIGINT NOT NULL,
  subtotal BIGINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- PAYMENTS
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  amount BIGINT NOT NULL,
  change_amount BIGINT DEFAULT 0,
  payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payment_method TEXT CHECK (payment_method IN ('cash', 'transfer', 'qris')) DEFAULT 'cash',
  notes TEXT,
  received_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- SYNC_QUEUE (untuk offline sync)
CREATE TABLE sync_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) NOT NULL,
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  action TEXT CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')) NOT NULL,
  data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  synced_at TIMESTAMPTZ
);
```

### Row Level Security (RLS)

```sql
-- Enable RLS
ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their outlet's data
CREATE POLICY "Users can view own outlet data" ON customers
  FOR ALL USING (
    outlet_id IN (
      SELECT outlet_id FROM users WHERE id = auth.uid()
    )
  );

-- Similar policies for other tables...
```

### Indexes

```sql
CREATE INDEX idx_orders_outlet_status ON orders(outlet_id, status);
CREATE INDEX idx_orders_outlet_date ON orders(outlet_id, order_date);
CREATE INDEX idx_customers_outlet_phone ON customers(outlet_id, phone);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
```

---

## Rencana Implementasi

### Phase 1: Setup & Foundation (Week 1-2)

```
📁 Struktur Folder Baru:

lib/
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   │   ├── database_helper.dart (existing)
│   │   │   └── local_datasource.dart (new)
│   │   └── remote/
│   │       ├── supabase_client.dart (new)
│   │       └── remote_datasource.dart (new)
│   ├── models/
│   │   └── ... (update with UUID support)
│   └── repositories/
│       └── ... (update with sync logic)
├── core/
│   └── services/
│       ├── sync_service.dart (new)
│       └── connectivity_service.dart (new)
```

**Tasks:**
- [ ] Setup Supabase project
- [ ] Tambah `supabase_flutter` dependency
- [ ] Buat Supabase client singleton
- [ ] Update models untuk support UUID
- [ ] Buat connectivity service

### Phase 2: Authentication Migration (Week 2-3)

**Tasks:**
- [ ] Implementasi Supabase Auth
- [ ] Migration dari username ke email
- [ ] Update AuthRepository
- [ ] Update AuthCubit
- [ ] Buat flow registrasi outlet baru
- [ ] Implementasi forgot password

```dart
// Contoh AuthRepository baru
class AuthRepository {
  final SupabaseClient _supabase;

  Future<User> signIn(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    // Get user profile from users table
    final profile = await _supabase
      .from('users')
      .select()
      .eq('id', response.user!.id)
      .single();
    return User.fromMap(profile);
  }
}
```

### Phase 3: Data Layer Refactoring (Week 3-4)

**Tasks:**
- [ ] Buat LocalDatasource (wrapper SQLite)
- [ ] Buat RemoteDatasource (wrapper Supabase)
- [ ] Update semua Repository dengan sync logic
- [ ] Implementasi sync queue
- [ ] Buat SyncService

```dart
// Contoh Repository Pattern Baru
class OrderRepository {
  final LocalDatasource _local;
  final RemoteDatasource _remote;
  final SyncService _sync;

  Future<Order> createOrder(Order order) async {
    // 1. Simpan ke lokal dulu (instant)
    final localOrder = await _local.insertOrder(order);

    // 2. Queue untuk sync
    await _sync.queueSync(
      table: 'orders',
      action: SyncAction.insert,
      data: localOrder.toMap(),
    );

    // 3. Trigger sync jika online
    _sync.syncIfOnline();

    return localOrder;
  }
}
```

### Phase 4: Sync Implementation (Week 4-5)

**Tasks:**
- [ ] Implementasi background sync
- [ ] Conflict resolution strategy
- [ ] Realtime subscriptions
- [ ] Sync status indicator di UI
- [ ] Retry mechanism untuk failed syncs

```dart
// Contoh SyncService
class SyncService {
  final LocalDatasource _local;
  final RemoteDatasource _remote;

  Future<void> syncAll() async {
    // 1. Push local changes
    final queue = await _local.getSyncQueue();
    for (final item in queue) {
      try {
        await _remote.sync(item);
        await _local.markSynced(item.id);
      } catch (e) {
        // Will retry next time
      }
    }

    // 2. Pull remote changes
    final lastSync = await _local.getLastSyncTime();
    final changes = await _remote.getChangesSince(lastSync);
    for (final change in changes) {
      await _local.applyRemoteChange(change);
    }
  }
}
```

### Phase 5: Multi-Outlet Support (Week 5-6)

**Tasks:**
- [ ] Buat OutletRepository
- [ ] Update semua query dengan outlet_id filter
- [ ] Buat outlet selection UI
- [ ] Implementasi invite user ke outlet
- [ ] Dashboard per outlet

### Phase 6: Testing & Polish (Week 6-7)

**Tasks:**
- [ ] Unit testing repositories
- [ ] Integration testing sync
- [ ] Offline scenario testing
- [ ] Performance optimization
- [ ] Error handling & logging
- [ ] User migration tool (untuk existing users)

### Phase 7: Deployment (Week 7-8)

**Tasks:**
- [ ] Setup Supabase production
- [ ] Database migration scripts
- [ ] App release dengan Supabase
- [ ] Dokumentasi untuk user
- [ ] Monitoring & analytics

---

## Estimasi Dependencies

### Tambahan di pubspec.yaml

```yaml
dependencies:
  # Supabase
  supabase_flutter: ^2.3.0

  # Connectivity
  connectivity_plus: ^5.0.0

  # Background sync (opsional)
  workmanager: ^0.5.0

  # Local storage for sync queue
  hive: ^2.2.0
  hive_flutter: ^1.1.0

dev_dependencies:
  # Testing
  mocktail: ^1.0.0
```

### Environment Variables

```
# .env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...
```

---

## Migration Path untuk Existing Users

### Opsi 1: Fresh Start (Recommended untuk v1)
- User baru dengan data baru
- Tidak perlu migrasi data lama

### Opsi 2: Data Export/Import
1. Export data dari SQLite ke JSON
2. User register di Supabase
3. Import JSON ke Supabase
4. Mapping ID lama ke UUID baru

### Opsi 3: Gradual Migration
1. App baru support both offline & online
2. User bisa pilih mode
3. Jika pilih online → migrate data

---

## Timeline Summary

| Phase | Durasi | Output |
|-------|--------|--------|
| 1. Setup & Foundation | 1-2 minggu | Supabase client, UUID models |
| 2. Authentication | 1 minggu | Email auth, registration |
| 3. Data Layer | 1-2 minggu | Repositories dengan sync |
| 4. Sync Implementation | 1-2 minggu | Full offline/online sync |
| 5. Multi-Outlet | 1 minggu | Outlet management |
| 6. Testing | 1 minggu | Tested & stable |
| 7. Deployment | 1 minggu | Production ready |

**Total: 7-10 minggu** untuk full implementation

---

## Alternatif Pendekatan

### Jika Ingin Lebih Cepat (MVP)

1. **Online-only mode** - Tanpa offline support
2. **Single outlet** - Tanpa multi-outlet
3. **Basic sync** - Tanpa realtime

Timeline: **3-4 minggu**

### Jika Ingin Lebih Robust

1. **Full offline-first** - Dengan proper conflict resolution
2. **Multi-outlet + multi-role** - Dengan kompleks permissions
3. **Realtime sync** - Dengan subscriptions
4. **Push notifications** - Order status updates

Timeline: **10-12 minggu**

---

## Kesimpulan

Integrasi Supabase akan mengubah aplikasi dari **offline-only** menjadi **hybrid offline-first** dengan kemampuan:

1. ✅ Data backup di cloud
2. ✅ Multi-device sync
3. ✅ Multi-outlet support
4. ✅ Tetap bisa offline
5. ✅ Authentication lebih secure
6. ✅ Scalable untuk growth

**Rekomendasi:** Mulai dengan **Phase 1-4** (MVP) dalam 4-5 minggu, lalu iterasi untuk fitur lanjutan.

---

<p align="center">
  <strong>Ready to go online!</strong><br/>
  Made with love by <a href="https://jagoflutter.com">JagoFlutter.com</a>
</p>
