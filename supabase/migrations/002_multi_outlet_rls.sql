-- =====================================================
-- MIGRATION: Multi-Outlet RLS Support
-- =====================================================
-- This migration updates RLS policies to support multi-outlet access
-- Owner can now access ALL outlets they own (not just profiles.outlet_id)
-- Kasir still limited to their assigned outlet from profiles table
-- =====================================================
-- Run this migration on existing Supabase databases
-- =====================================================

-- =====================================================
-- DROP EXISTING POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Users can view own outlet" ON outlets;
DROP POLICY IF EXISTS "Users can update own outlet" ON outlets;
DROP POLICY IF EXISTS "Users can delete own outlet" ON outlets;
DROP POLICY IF EXISTS "Anyone can create outlet" ON outlets;

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
-- OUTLETS POLICIES (Multi-Outlet)
-- =====================================================
-- Owner can view ALL outlets they own
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
-- CUSTOMERS POLICIES (Multi-Outlet)
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
-- SERVICES POLICIES (Multi-Outlet)
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
-- ORDERS POLICIES (Multi-Outlet)
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
-- ORDER ITEMS POLICIES (Multi-Outlet)
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
-- PAYMENTS POLICIES (Multi-Outlet)
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
-- APP SETTINGS POLICIES (Multi-Outlet)
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
-- LOCAL USERS POLICIES (Multi-Outlet)
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
-- DONE!
-- =====================================================
-- After running this migration:
-- - Owner can now access data from ALL outlets they own
-- - Kasir still restricted to their assigned outlet
-- - Security maintained: owner_id check ensures users can only
--   access outlets they own
-- =====================================================
