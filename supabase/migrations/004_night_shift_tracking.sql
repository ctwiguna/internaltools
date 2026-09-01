-- =====================================================
-- MIGRATION: Night Shift GPS Tracking & Asset Handover
-- =====================================================
-- Dipakai oleh app kedua (flutter_laundry_nightshift_app) untuk pegawai
-- shift malam. Semua perubahan di sini ADDITIVE/NULLABLE terhadap tabel
-- existing (outlets, attendance) -- tidak mengubah behavior app POS utama.
--
-- Cakupan fitur:
-- - Lokasi outlet (lat/lng/radius) untuk hitung geofence.
-- - Kolom check-out & consent lokasi pada tabel attendance (belum pernah
--   ada konsep check-out sebelum migration ini).
-- - shift_locations: trail ping GPS selama shift aktif.
-- - geofence_alerts: event saat pegawai keluar radius outlet sebelum jam
--   cutoff (default 06:00, dikonfigurasi lewat app_settings key
--   'night_shift_end_hour' per outlet -- lihat tabel app_settings existing).
-- - asset_handovers: checklist serah-terima aset saat clock-out.
--
-- `id` pada tabel baru diisi client (uuid v4) mengikuti pola tabel
-- attendance/order_cancellation_requests -- BUKAN cuma default server,
-- supaya insert dari device tetap idempoten kalau retry.
-- =====================================================

-- =====================================================
-- 1. OUTLETS: lokasi & radius geofence
-- =====================================================
ALTER TABLE outlets
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS geofence_radius_m INTEGER DEFAULT 150;

-- =====================================================
-- 2. ATTENDANCE: shift type, check-out, consent lokasi
-- =====================================================
ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS shift_type TEXT CHECK (shift_type IN ('day', 'night')) DEFAULT 'day',
  ADD COLUMN IF NOT EXISTS check_out_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS check_out_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS check_out_lng DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_consent_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_attendance_active_night_shift
  ON attendance(outlet_id, shift_type, check_out_at);

-- =====================================================
-- 3. SHIFT_LOCATIONS: trail ping GPS selama shift aktif
-- =====================================================
CREATE TABLE IF NOT EXISTS shift_locations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  attendance_id UUID REFERENCES attendance(id) ON DELETE CASCADE NOT NULL,
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy_m DOUBLE PRECISION,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shift_locations_attendance
  ON shift_locations(attendance_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_shift_locations_outlet
  ON shift_locations(outlet_id, recorded_at DESC);

-- =====================================================
-- 4. GEOFENCE_ALERTS: event keluar radius outlet
-- =====================================================
CREATE TABLE IF NOT EXISTS geofence_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  attendance_id UUID REFERENCES attendance(id) ON DELETE CASCADE NOT NULL,
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  distance_m DOUBLE PRECISION NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  acknowledged_at TIMESTAMPTZ,
  acknowledged_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_geofence_alerts_outlet
  ON geofence_alerts(outlet_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_geofence_alerts_attendance
  ON geofence_alerts(attendance_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_geofence_alerts_unacked
  ON geofence_alerts(outlet_id, acknowledged_at);

-- =====================================================
-- 5. ASSET_HANDOVERS: checklist serah-terima saat clock-out
-- =====================================================
CREATE TABLE IF NOT EXISTS asset_handovers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  attendance_id UUID REFERENCES attendance(id) ON DELETE CASCADE NOT NULL,
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name TEXT NOT NULL,
  checklist JSONB NOT NULL DEFAULT '[]',
  cash_amount BIGINT DEFAULT 0,
  notes TEXT,
  checkout_lat DOUBLE PRECISION,
  checkout_lng DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_asset_handovers_attendance
  ON asset_handovers(attendance_id);
CREATE INDEX IF NOT EXISTS idx_asset_handovers_outlet
  ON asset_handovers(outlet_id, created_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE shift_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE geofence_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE asset_handovers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view outlet shift_locations" ON shift_locations;
DROP POLICY IF EXISTS "Users can insert outlet shift_locations" ON shift_locations;
DROP POLICY IF EXISTS "Users can view outlet geofence_alerts" ON geofence_alerts;
DROP POLICY IF EXISTS "Users can insert outlet geofence_alerts" ON geofence_alerts;
DROP POLICY IF EXISTS "Owner can acknowledge outlet geofence_alerts" ON geofence_alerts;
DROP POLICY IF EXISTS "Users can view outlet asset_handovers" ON asset_handovers;
DROP POLICY IF EXISTS "Users can insert outlet asset_handovers" ON asset_handovers;

-- SHIFT_LOCATIONS: owner lihat semua outlet miliknya, kasir hanya outletnya
-- sendiri. INSERT dibolehkan kasir/owner untuk outlet sendiri (device
-- pegawai yang menulis ping GPS selama shift).
CREATE POLICY "Users can view outlet shift_locations" ON shift_locations
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can insert outlet shift_locations" ON shift_locations
  FOR INSERT WITH CHECK (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- Tidak ada policy UPDATE/DELETE -- trail lokasi bersifat append-only.

-- GEOFENCE_ALERTS: sama seperti shift_locations untuk SELECT/INSERT.
CREATE POLICY "Users can view outlet geofence_alerts" ON geofence_alerts
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can insert outlet geofence_alerts" ON geofence_alerts
  FOR INSERT WITH CHECK (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- UPDATE (acknowledge): SENGAJA hanya owner, sama seperti pola approve/
-- reject di order_cancellation_requests. Kasir tidak boleh menghilangkan
-- alert atas dirinya sendiri.
CREATE POLICY "Owner can acknowledge outlet geofence_alerts" ON geofence_alerts
  FOR UPDATE USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
  );

-- ASSET_HANDOVERS: sama seperti shift_locations, append-only (tidak ada
-- policy UPDATE/DELETE -- checklist serah-terima tidak boleh diubah lagi
-- setelah disubmit, ini catatan resmi serah-terima aset).
CREATE POLICY "Users can view outlet asset_handovers" ON asset_handovers
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can insert outlet asset_handovers" ON asset_handovers
  FOR INSERT WITH CHECK (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- =====================================================
-- DONE!
-- =====================================================
-- Cara pakai:
-- 1. Jalankan file ini SEKALI di Supabase SQL Editor (project yang sama
--    dengan app existing).
-- 2. Isi lat/lng/radius tiap outlet lewat app existing (Settings > Kelola
--    Outlet) sebelum app shift malam dipakai -- kalau kosong, evaluasi
--    geofence di app shift malam tidak akan berjalan untuk outlet itu.
-- 3. (Opsional) atur jam cutoff custom per outlet lewat tabel app_settings
--    existing: key = 'night_shift_end_hour', value = '6' (jam, 24h format).
--    Kalau tidak diisi, default 6 dipakai oleh app.
-- =====================================================
