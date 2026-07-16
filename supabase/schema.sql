-- =====================================================
-- LAUNDRY JAGOFLUTTER - SUPABASE FULL SCHEMA
-- =====================================================
-- IMPORTANT: This is the COMPLETE schema.
-- Run this ONCE in Supabase SQL Editor for new projects.
-- The migrations folder contains incremental updates for
-- existing databases, but this file already includes them.
-- =====================================================
-- Last updated: January 2025
-- Features included:
-- - Multi-outlet support (owner can have multiple outlets)
-- - User profiles with roles (owner/kasir)
-- - Customers, Services, Orders, Payments
-- - Local users sync (for offline kasir accounts)
-- - Row Level Security (RLS) policies (multi-outlet aware)
-- - Auto-triggers for updated_at and new user registration
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. OUTLETS TABLE (untuk multi-outlet support)
-- =====================================================
-- Setiap outlet adalah cabang laundry yang terpisah
-- Owner bisa memiliki beberapa outlet
CREATE TABLE IF NOT EXISTS outlets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  invoice_prefix TEXT DEFAULT 'INV',
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 2. PROFILES TABLE (extends auth.users)
-- =====================================================
-- Profile untuk setiap user yang login via Supabase Auth
-- Role: 'owner' = pemilik, 'kasir' = karyawan
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES outlets(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  role TEXT CHECK (role IN ('owner', 'kasir')) DEFAULT 'kasir',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 3. CUSTOMERS TABLE
-- =====================================================
-- Data pelanggan per outlet
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  notes TEXT,
  total_orders INTEGER DEFAULT 0,
  total_spent BIGINT DEFAULT 0,
  last_order_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 4. SERVICES TABLE
-- =====================================================
-- Paket layanan laundry per outlet
-- Unit: 'kg' untuk cuci kiloan, 'pcs' untuk satuan
CREATE TABLE IF NOT EXISTS services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  unit TEXT CHECK (unit IN ('kg', 'pcs')) DEFAULT 'kg',
  price BIGINT NOT NULL,
  duration_days INTEGER DEFAULT 3,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 5. ORDERS TABLE
-- =====================================================
-- Order laundry per outlet
-- Status flow: pending -> process -> ready -> done
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
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
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(outlet_id, invoice_no)
);

-- =====================================================
-- 6. ORDER_ITEMS TABLE
-- =====================================================
-- Item detail per order
CREATE TABLE IF NOT EXISTS order_items (
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

-- =====================================================
-- 7. PAYMENTS TABLE
-- =====================================================
-- Pembayaran per order (bisa bayar bertahap)
-- change_amount = uang kembalian (jika bayar lebih)
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  amount BIGINT NOT NULL,
  change_amount BIGINT DEFAULT 0,
  payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payment_method TEXT CHECK (payment_method IN ('cash', 'transfer', 'qris')) DEFAULT 'cash',
  notes TEXT,
  received_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 8. APP_SETTINGS TABLE
-- =====================================================
-- Pengaturan aplikasi per outlet (key-value)
CREATE TABLE IF NOT EXISTS app_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
  key TEXT NOT NULL,
  value TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(outlet_id, key)
);

-- =====================================================
-- 9. LOCAL_USERS TABLE (for syncing kasir accounts)
-- =====================================================
-- Menyimpan akun kasir lokal yang perlu di-sync antar device
-- Akun owner TIDAK disimpan di sini (pakai Supabase Auth)
-- Password di-hash dengan bcrypt di sisi client
CREATE TABLE IF NOT EXISTS local_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
  username TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT CHECK (role IN ('owner', 'kasir')) DEFAULT 'kasir',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(outlet_id, username)
);

-- =====================================================
-- 10. SYNC_QUEUE TABLE (optional - for debugging)
-- =====================================================
-- Bisa digunakan untuk melacak sync yang gagal dari client
-- Ini opsional, sync queue utama ada di SQLite client
-- CREATE TABLE IF NOT EXISTS sync_queue (
--   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
--   table_name TEXT NOT NULL,
--   operation TEXT CHECK (operation IN ('insert', 'update', 'delete')) NOT NULL,
--   local_id INTEGER NOT NULL,
--   data JSONB,
--   error_message TEXT,
--   retry_count INTEGER DEFAULT 0,
--   created_at TIMESTAMPTZ DEFAULT NOW()
-- );

-- =====================================================
-- INDEXES
-- =====================================================
-- Indexes untuk mempercepat query yang sering dipakai

-- Profiles
CREATE INDEX IF NOT EXISTS idx_profiles_outlet ON profiles(outlet_id);

-- Customers
CREATE INDEX IF NOT EXISTS idx_customers_outlet ON customers(outlet_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(outlet_id, phone);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(outlet_id, name);

-- Services
CREATE INDEX IF NOT EXISTS idx_services_outlet ON services(outlet_id);
CREATE INDEX IF NOT EXISTS idx_services_active ON services(outlet_id, is_active);

-- Orders
CREATE INDEX IF NOT EXISTS idx_orders_outlet_status ON orders(outlet_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_outlet_date ON orders(outlet_id, order_date DESC);
CREATE INDEX IF NOT EXISTS idx_orders_invoice ON orders(outlet_id, invoice_no);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);

-- Order Items
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_service ON order_items(service_id);

-- Payments
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date DESC);

-- Local Users
CREATE INDEX IF NOT EXISTS idx_local_users_outlet ON local_users(outlet_id);
CREATE INDEX IF NOT EXISTS idx_local_users_username ON local_users(outlet_id, username);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================
-- RLS memastikan user hanya bisa akses data outlet mereka

-- Enable RLS on all tables
ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE local_users ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- DROP EXISTING POLICIES (for safe re-run)
-- =====================================================
DROP POLICY IF EXISTS "Users can view own outlet" ON outlets;
DROP POLICY IF EXISTS "Users can update own outlet" ON outlets;
DROP POLICY IF EXISTS "Users can delete own outlet" ON outlets;
DROP POLICY IF EXISTS "Anyone can create outlet" ON outlets;
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Outlet members can view each other" ON profiles;
DROP POLICY IF EXISTS "Users can view outlet customers" ON customers;
DROP POLICY IF EXISTS "Users can manage outlet customers" ON customers;
DROP POLICY IF EXISTS "Users can view outlet services" ON services;
DROP POLICY IF EXISTS "Users can manage outlet services" ON services;
DROP POLICY IF EXISTS "Users can view outlet orders" ON orders;
DROP POLICY IF EXISTS "Users can manage outlet orders" ON orders;
DROP POLICY IF EXISTS "Users can view order items" ON order_items;
DROP POLICY IF EXISTS "Users can manage order items" ON order_items;
DROP POLICY IF EXISTS "Users can view payments" ON payments;
DROP POLICY IF EXISTS "Users can manage payments" ON payments;
DROP POLICY IF EXISTS "Users can view outlet settings" ON app_settings;
DROP POLICY IF EXISTS "Users can manage outlet settings" ON app_settings;
DROP POLICY IF EXISTS "Users can view outlet local_users" ON local_users;
DROP POLICY IF EXISTS "Users can manage outlet local_users" ON local_users;

-- =====================================================
-- OUTLETS POLICIES
-- =====================================================
-- Owner can view ALL outlets they own (multi-outlet support)
CREATE POLICY "Users can view own outlet" ON outlets
  FOR SELECT USING (
    owner_id = auth.uid()
    OR id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- Owner can update ALL outlets they own
CREATE POLICY "Users can update own outlet" ON outlets
  FOR UPDATE USING (owner_id = auth.uid());

-- Owner can delete their outlets
CREATE POLICY "Users can delete own outlet" ON outlets
  FOR DELETE USING (owner_id = auth.uid());

-- Anyone authenticated can create outlet
CREATE POLICY "Anyone can create outlet" ON outlets
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- =====================================================
-- PROFILES POLICIES
-- =====================================================
-- IMPORTANT: Keep these simple to avoid infinite recursion
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (id = auth.uid());

-- Allow insert for new user registration (trigger needs this)
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (true);

-- Note: "Outlet members can view each other" policy is removed to avoid recursion
-- If needed, use a SECURITY DEFINER function to fetch team members

-- =====================================================
-- CUSTOMERS POLICIES
-- =====================================================
-- Owner can access customers from ALL their outlets
-- Kasir can only access customers from their assigned outlet
CREATE POLICY "Users can view outlet customers" ON customers
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can manage outlet customers" ON customers
  FOR ALL USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- =====================================================
-- SERVICES POLICIES
-- =====================================================
-- Owner can access services from ALL their outlets
-- Kasir can only access services from their assigned outlet
CREATE POLICY "Users can view outlet services" ON services
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can manage outlet services" ON services
  FOR ALL USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- =====================================================
-- ORDERS POLICIES
-- =====================================================
-- Owner can access orders from ALL their outlets
-- Kasir can only access orders from their assigned outlet
CREATE POLICY "Users can view outlet orders" ON orders
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can manage outlet orders" ON orders
  FOR ALL USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- =====================================================
-- ORDER ITEMS POLICIES
-- =====================================================
-- Access follows parent order's outlet access rules
CREATE POLICY "Users can view order items" ON order_items
  FOR SELECT USING (
    order_id IN (
      SELECT id FROM orders WHERE
        outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
        OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
    )
  );

CREATE POLICY "Users can manage order items" ON order_items
  FOR ALL USING (
    order_id IN (
      SELECT id FROM orders WHERE
        outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
        OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
    )
  );

-- =====================================================
-- PAYMENTS POLICIES
-- =====================================================
-- Access follows parent order's outlet access rules
CREATE POLICY "Users can view payments" ON payments
  FOR SELECT USING (
    order_id IN (
      SELECT id FROM orders WHERE
        outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
        OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
    )
  );

CREATE POLICY "Users can manage payments" ON payments
  FOR ALL USING (
    order_id IN (
      SELECT id FROM orders WHERE
        outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
        OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
    )
  );

-- =====================================================
-- APP SETTINGS POLICIES
-- =====================================================
-- Owner can access settings from ALL their outlets
-- Kasir can only access settings from their assigned outlet
CREATE POLICY "Users can view outlet settings" ON app_settings
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can manage outlet settings" ON app_settings
  FOR ALL USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- =====================================================
-- LOCAL USERS POLICIES
-- =====================================================
-- Owner can manage kasir accounts from ALL their outlets
-- Kasir can only view their own outlet's local users
CREATE POLICY "Users can view outlet local_users" ON local_users
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can manage outlet local_users" ON local_users
  FOR ALL USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Function to update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle new user registration
-- IMPORTANT: SECURITY DEFINER bypasses RLS during trigger execution
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_outlet_id UUID;
BEGIN
  -- Create a new outlet for the user
  INSERT INTO outlets (name, owner_id)
  VALUES (COALESCE(NEW.raw_user_meta_data->>'laundry_name', 'My Laundry'), NEW.id)
  RETURNING id INTO new_outlet_id;

  -- Create profile for the user
  INSERT INTO profiles (id, outlet_id, name, role)
  VALUES (
    NEW.id,
    new_outlet_id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    'owner'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Triggers for auto-updating updated_at column
DROP TRIGGER IF EXISTS update_outlets_updated_at ON outlets;
CREATE TRIGGER update_outlets_updated_at
  BEFORE UPDATE ON outlets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_customers_updated_at ON customers;
CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_services_updated_at ON services;
CREATE TRIGGER update_services_updated_at
  BEFORE UPDATE ON services
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_app_settings_updated_at ON app_settings;
CREATE TRIGGER update_app_settings_updated_at
  BEFORE UPDATE ON app_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_local_users_updated_at ON local_users;
CREATE TRIGGER update_local_users_updated_at
  BEFORE UPDATE ON local_users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Trigger for new user registration (auto-create outlet & profile)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =====================================================
-- DONE!
-- =====================================================
-- After running this script:
-- 1. Go to Authentication > Providers
-- 2. Enable Email provider
-- 3. Disable "Confirm email" for testing (optional)
-- 4. Copy URL and anon key to your Flutter app .env file
-- =====================================================
