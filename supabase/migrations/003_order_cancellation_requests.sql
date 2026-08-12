-- =====================================================
-- MIGRATION: Order Cancellation Requests
-- =====================================================
-- Kasir mengajukan pembatalan order -> owner review -> approve/reject.
-- Saat di-approve, order aslinya DIHAPUS (lihat lib/data/repositories/
-- hybrid_order_repository.dart deleteOrder) tapi baris di tabel ini tetap
-- ada sebagai riwayat ("Dibatalkan"), karena order_id di-SET NULL bukan
-- CASCADE saat order induknya dihapus.
--
-- `id` diisi client (uuid v4), mengikuti pola tabel attendance/shifts/
-- cash_expenses (lihat lib/data/repositories/ops_repository.dart) —
-- BUKAN uuid_generate_v4() server, supaya sync lokal->cloud idempoten.
-- =====================================================

CREATE TABLE IF NOT EXISTS order_cancellation_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE NOT NULL,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  invoice_no TEXT NOT NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  total_price BIGINT NOT NULL,
  paid BIGINT DEFAULT 0,
  order_snapshot JSONB NOT NULL,
  reason TEXT,
  status TEXT CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
  requested_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  requested_by_name TEXT NOT NULL,
  reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_by_name TEXT,
  review_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_cancel_requests_outlet_status
  ON order_cancellation_requests(outlet_id, status);
CREATE INDEX IF NOT EXISTS idx_cancel_requests_order
  ON order_cancellation_requests(order_id);

ALTER TABLE order_cancellation_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view outlet cancellation requests" ON order_cancellation_requests;
DROP POLICY IF EXISTS "Users can create outlet cancellation requests" ON order_cancellation_requests;
DROP POLICY IF EXISTS "Owner can review outlet cancellation requests" ON order_cancellation_requests;

-- SELECT: owner melihat semua outlet miliknya, kasir hanya outletnya sendiri
CREATE POLICY "Users can view outlet cancellation requests" ON order_cancellation_requests
  FOR SELECT USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- INSERT: kasir & owner boleh mengajukan pembatalan untuk outlet mereka
CREATE POLICY "Users can create outlet cancellation requests" ON order_cancellation_requests
  FOR INSERT WITH CHECK (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
    OR outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid())
  );

-- UPDATE (approve/reject): SENGAJA hanya owner. Tidak ada policy UPDATE
-- untuk kasir sama sekali, supaya kasir tidak bisa mengubah status
-- pengajuannya sendiri setelah dikirim.
CREATE POLICY "Owner can review outlet cancellation requests" ON order_cancellation_requests
  FOR UPDATE USING (
    outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid())
  );

-- Tidak ada policy DELETE — baik kasir maupun owner tidak boleh menghapus
-- jejak riwayat pembatalan.

-- =====================================================
-- DONE!
-- =====================================================
