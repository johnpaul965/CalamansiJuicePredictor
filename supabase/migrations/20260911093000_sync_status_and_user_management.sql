/*
  # Synchronize User Status and Predictions Schema with Supabase SQL

  1. Add `status` column to `app_users` table ('Active' | 'Suspended') with default 'Active'.
  2. Add `size_label` column to `predictions` table for readable calamansi grading records.
  3. Seed default accounts with deterministic UUIDs and SHA-256 passwords:
     - admin (admin123)
     - farmer_juan (user123)
     - tacloban_vendor (user123)
  4. Ensure RLS policies allow full user management (SELECT, INSERT, UPDATE, DELETE).
*/

-- 1. Add status column to app_users if not exists
ALTER TABLE app_users 
ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'Active';

-- 2. Add size_label column to predictions if not exists
ALTER TABLE predictions 
ADD COLUMN IF NOT EXISTS size_label text DEFAULT 'Medium Calamansi (10–14g)';

-- 3. Seed / upsert default accounts with deterministic UUIDs and SHA-256 passwords
-- admin123 -> 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
-- user123  -> a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3

INSERT INTO app_users (id, username, password, role, status)
VALUES 
  ('00000000-0000-0000-0000-000000000001', 'admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'admin', 'Active'),
  ('00000000-0000-0000-0000-000000000002', 'farmer_juan', 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', 'user', 'Active'),
  ('00000000-0000-0000-0000-000000000003', 'tacloban_vendor', 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', 'user', 'Active')
ON CONFLICT (username) DO UPDATE 
SET 
  role = EXCLUDED.role,
  status = COALESCE(app_users.status, 'Active');

-- 4. Enable RLS and verify policies
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE predictions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_app_users" ON app_users;
CREATE POLICY "read_app_users" ON app_users FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "insert_app_users" ON app_users;
CREATE POLICY "insert_app_users" ON app_users FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "update_app_users" ON app_users;
CREATE POLICY "update_app_users" ON app_users FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "delete_app_users" ON app_users;
CREATE POLICY "delete_app_users" ON app_users FOR DELETE TO anon, authenticated USING (true);

-- Ensure predictions are accessible to both anon and authenticated users
DROP POLICY IF EXISTS "select_predictions" ON predictions;
CREATE POLICY "select_predictions" ON predictions FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "insert_predictions" ON predictions;
CREATE POLICY "insert_predictions" ON predictions FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "delete_predictions" ON predictions;
CREATE POLICY "delete_predictions" ON predictions FOR DELETE TO anon, authenticated USING (true);
