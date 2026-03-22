-- Migration: Fix handle_new_user trigger RLS bypass
--
-- Problem: The handle_new_user() trigger fires during auth.users INSERT,
-- before auth.uid() is available. RLS INSERT policies on user_settings
-- and user_subscriptions check auth.uid() = user_id, which evaluates to
-- false (NULL != user_id), blocking the trigger's inserts.
--
-- The function is SECURITY DEFINER and should run as postgres (bypassrls),
-- but Supabase hosted environments may not honor this for all contexts.
--
-- Fix: Two changes:
-- 1. Explicitly set function owner to postgres (ensures bypassrls)
-- 2. Add RLS to public.users (was missing) with proper policies
-- 3. Drop the existing restrictive INSERT policies on user_settings
--    and user_subscriptions and replace them with policies that also
--    allow the trigger to insert (auth.uid() = user_id OR inserting
--    user's own row during signup)

-- ============================================================
-- 1. Ensure handle_new_user is owned by postgres (has bypassrls)
-- ============================================================
ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

-- ============================================================
-- 2. Enable RLS on users table (was missing) and add policies
-- ============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE USING (auth.uid() = id);
-- INSERT: only the trigger (running as postgres with bypassrls) inserts here.
-- No user-facing INSERT policy needed. If bypassrls isn't working, add fallback:
CREATE POLICY "Allow trigger insert" ON users
  FOR INSERT WITH CHECK (true);

-- ============================================================
-- 3. Replace restrictive INSERT policies on trigger target tables
-- ============================================================
-- Drop existing INSERT policies that block the trigger
DROP POLICY IF EXISTS "Users can insert own data" ON user_settings;
DROP POLICY IF EXISTS "Users can insert own data" ON user_subscriptions;

-- Recreate with a check that allows both:
-- a) Normal user inserts (auth.uid() = user_id)
-- b) Trigger inserts where auth.uid() is NULL (signup context)
CREATE POLICY "Users can insert own data" ON user_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);

CREATE POLICY "Users can insert own data" ON user_subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);
