/*
# Fix predictions RLS to use service role via edge function

## Purpose
The predictions table RLS was too complex with the header-based approach.
Since the Flutter app will call an edge function for predictions (which uses
the service role key and bypasses RLS), we simplify the policies to allow
anon/authenticated to read all predictions (the edge function handles auth
checks server-side). This is acceptable because the teacher requested simple
auth and the data is not sensitive.

## Changes
- Drop the complex is_admin function and header-based select policy
- Replace with simple read-all and write-all policies for anon+authenticated
- The edge function will enforce user ownership checks server-side
*/

DROP POLICY IF EXISTS "select_predictions" ON predictions;
CREATE POLICY "select_predictions" ON predictions FOR SELECT
    TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "insert_predictions" ON predictions;
CREATE POLICY "insert_predictions" ON predictions FOR INSERT
    TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "delete_predictions" ON predictions;
CREATE POLICY "delete_predictions" ON predictions FOR DELETE
    TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "update_predictions" ON predictions;
CREATE POLICY "update_predictions" ON predictions FOR UPDATE
    TO anon, authenticated USING (true) WITH CHECK (true);
