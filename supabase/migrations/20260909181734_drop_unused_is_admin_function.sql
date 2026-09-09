-- Drop the unused is_admin SECURITY DEFINER function
-- It was created in the first migration but is no longer referenced
-- by any RLS policy (the second migration replaced header-based checks
-- with simple open policies enforced server-side by the edge function).
DROP FUNCTION IF EXISTS is_admin(uuid);
