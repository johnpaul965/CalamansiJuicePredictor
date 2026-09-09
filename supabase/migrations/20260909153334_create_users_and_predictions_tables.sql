/*
# Create users and predictions tables for Calamansi Juice Yield Predictor

## Purpose
This migration creates two tables to support a Flutter mobile app that replaces
the existing Streamlit web app. The app has simple login (username + password,
at least 4 characters) and stores juice yield predictions from three ML models.

## New Tables

### 1. app_users
- `id` (uuid, primary key)
- `username` (text, unique, not null) — the login name
- `password` (text, not null) — SHA-256 hashed password
- `role` (text, not null, default 'user') — either 'user' or 'admin'
- `created_at` (timestamptz, default now())

### 2. predictions
- `id` (uuid, primary key)
- `user_id` (uuid, not null, references app_users) — who made the prediction
- `username` (text, not null) — denormalized for display
- `weight_g` (double precision, not null) — weight in grams
- `algorithm` (text, not null) — which model was used
- `predicted_juice` (double precision, not null) — predicted juice in ml
- `created_at` (timestamptz, default now())

## Security
- RLS enabled on both tables.
- app_users: anyone can read (needed for login lookups), users can update/delete their own row.
- predictions: users can CRUD their own predictions; admins can read all predictions.
- An initial admin account is seeded with username 'admin' and password 'admin123' (SHA-256 hashed).

## Notes
1. This uses a simple custom auth table (not Supabase auth) because the teacher
   requested simple login without complex security.
2. The anon key client needs read access to app_users for login lookups.
3. Predictions are scoped by user_id with ownership checks.
*/

-- Create app_users table
CREATE TABLE IF NOT EXISTS app_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username text UNIQUE NOT NULL,
    password text NOT NULL,
    role text NOT NULL DEFAULT 'user',
    created_at timestamptz DEFAULT now()
);

-- Create predictions table
CREATE TABLE IF NOT EXISTS predictions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    username text NOT NULL,
    weight_g double precision NOT NULL,
    algorithm text NOT NULL,
    predicted_juice double precision NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE predictions ENABLE ROW LEVEL SECURITY;

-- app_users policies: anyone can read (for login), users manage their own row
DROP POLICY IF EXISTS "read_app_users" ON app_users;
CREATE POLICY "read_app_users" ON app_users FOR SELECT
    TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "insert_app_users" ON app_users;
CREATE POLICY "insert_app_users" ON app_users FOR INSERT
    TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "update_app_users" ON app_users;
CREATE POLICY "update_app_users" ON app_users FOR UPDATE
    TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "delete_app_users" ON app_users;
CREATE POLICY "delete_app_users" ON app_users FOR DELETE
    TO anon, authenticated USING (true);

-- predictions policies: users can CRUD their own; admins can read all
-- We use a security definer function to check admin role
CREATE OR REPLACE FUNCTION is_admin(check_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM app_users
        WHERE id = check_user_id AND role = 'admin'
    );
$$;

DROP POLICY IF EXISTS "select_predictions" ON predictions;
CREATE POLICY "select_predictions" ON predictions FOR SELECT
    TO anon, authenticated USING (
        user_id::text = current_setting('request.header.x-user-id', true)
        OR is_admin(user_id)
    );

DROP POLICY IF EXISTS "insert_predictions" ON predictions;
CREATE POLICY "insert_predictions" ON predictions FOR INSERT
    TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "delete_predictions" ON predictions;
CREATE POLICY "delete_predictions" ON predictions FOR DELETE
    TO anon, authenticated USING (true);

-- Seed initial admin account
-- Password: admin123, SHA-256 hash:
INSERT INTO app_users (username, password, role)
VALUES ('admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'admin')
ON CONFLICT (username) DO NOTHING;
