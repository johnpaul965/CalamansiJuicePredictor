/*
# Create dataset_rows and model_state tables

## Purpose
Stores the calamansi training dataset (Weight, Size, Juice) in the cloud so admins
can add new measurements from the mobile app. When new data is added, the models
are retrained automatically by the retrain edge function.

## New Tables

### 1. dataset_rows
- `id` (uuid, primary key)
- `weight` (double precision, not null) — weight in grams
- `size` (integer, not null) — 1=Small, 2=Medium, 3=Large
- `juice` (double precision, not null) — juice yield in ml
- `created_at` (timestamptz, default now())

### 2. model_state
- `id` (integer, primary key, always 1 — singleton row)
- `coefficients` (jsonb, not null) — serialized model coefficients for all 3 models
- `metrics` (jsonb, not null) — evaluation metrics (R², MAE) for all 3 models
- `best_model` (text, not null) — name of the best-performing model
- `dataset_rows` (integer, not null) — number of training rows used
- `training_samples` (integer, not null)
- `test_samples` (integer, not null)
- `size_dist` (jsonb, not null) — count of Small/Medium/Large
- `updated_at` (timestamptz, default now())

## Security
- RLS enabled on both tables.
- dataset_rows: anyone can read (app needs to display data); only anon/authenticated can insert and delete (admin manages via app).
- model_state: anyone can read (app needs metrics for display); only anon/authenticated can update (retrain function writes).
*/

CREATE TABLE IF NOT EXISTS dataset_rows (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    weight double precision NOT NULL,
    size integer NOT NULL,
    juice double precision NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS model_state (
    id integer PRIMARY KEY DEFAULT 1,
    coefficients jsonb NOT NULL,
    metrics jsonb NOT NULL,
    best_model text NOT NULL,
    dataset_rows integer NOT NULL,
    training_samples integer NOT NULL,
    test_samples integer NOT NULL,
    size_dist jsonb NOT NULL,
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT single_row CHECK (id = 1)
);

ALTER TABLE dataset_rows ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_state ENABLE ROW LEVEL SECURITY;

-- dataset_rows policies
DROP POLICY IF EXISTS "select_dataset_rows" ON dataset_rows;
CREATE POLICY "select_dataset_rows" ON dataset_rows FOR SELECT
    TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "insert_dataset_rows" ON dataset_rows;
CREATE POLICY "insert_dataset_rows" ON dataset_rows FOR INSERT
    TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "delete_dataset_rows" ON dataset_rows;
CREATE POLICY "delete_dataset_rows" ON dataset_rows FOR DELETE
    TO anon, authenticated USING (true);

-- model_state policies
DROP POLICY IF EXISTS "select_model_state" ON model_state;
CREATE POLICY "select_model_state" ON model_state FOR SELECT
    TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "update_model_state" ON model_state;
CREATE POLICY "update_model_state" ON model_state FOR UPDATE
    TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "insert_model_state" ON model_state;
CREATE POLICY "insert_model_state" ON model_state FOR INSERT
    TO anon, authenticated WITH CHECK (true);
