-- Migration: Security Fixes
-- Fixes all Supabase linter errors and warnings from the initial deploy.
-- 1. Security Definer Views → recreated with SECURITY INVOKER
-- 2. RLS Disabled → enabled on users, global_currencies, exchange_rates
-- 3. Mutable Search Path → all functions recreated with SET search_path = public

-- ============================================================
-- 1. SECURITY INVOKER VIEWS
-- Drop and recreate all three views with explicit SECURITY INVOKER
-- so they run under the calling user's permissions, not the definer's.
-- ============================================================

DROP VIEW IF EXISTS expense_transaction_inbox_view;
DROP VIEW IF EXISTS expense_categories_with_counts;
DROP VIEW IF EXISTS note_entries_with_notebooks;

-- Joins inbox items with account, category, and linked task details
CREATE VIEW expense_transaction_inbox_view
WITH (security_invoker = true)
AS
SELECT
  i.*,
  a.name AS account_name,
  a.currency_code,
  c.name AS category_name,
  t.due_date AS task_due_date
FROM expense_transaction_inbox i
LEFT JOIN expense_bank_accounts a ON i.account_id = a.id
LEFT JOIN expense_categories c ON i.category_id = c.id
LEFT JOIN todo_tasks t ON i.linked_task_id = t.id
WHERE i.deleted_at IS NULL;

-- Categories with their transaction counts
CREATE VIEW expense_categories_with_counts
WITH (security_invoker = true)
AS
SELECT
  c.*,
  COUNT(t.id) FILTER (WHERE t.deleted_at IS NULL) AS transaction_count
FROM expense_categories c
LEFT JOIN expense_transactions t ON c.id = t.category_id
WHERE c.deleted_at IS NULL
GROUP BY c.id;

-- Notes joined with their notebook details
CREATE VIEW note_entries_with_notebooks
WITH (security_invoker = true)
AS
SELECT
  n.*,
  nb.name AS notebook_name,
  nb.color AS notebook_color
FROM note_entries n
LEFT JOIN note_notebooks nb ON n.notebook_id = nb.id
WHERE n.deleted_at IS NULL;

-- ============================================================
-- 2. RLS ON PREVIOUSLY UNPROTECTED TABLES
-- ============================================================

-- --- users ---
-- Auth-managed table. Users can only read their own row.
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own row" ON users
  FOR SELECT USING (auth.uid() = id);

-- --- global_currencies ---
-- Static lookup table. All authenticated users can read.
ALTER TABLE global_currencies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read currencies" ON global_currencies
  FOR SELECT USING (auth.role() = 'authenticated');

-- --- exchange_rates ---
-- Append-only reference table. All authenticated users can read.
ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read exchange rates" ON exchange_rates
  FOR SELECT USING (auth.role() = 'authenticated');

-- ============================================================
-- 3. IMMUTABLE SEARCH PATH ON ALL FUNCTIONS
-- Recreate all four functions with SET search_path = public
-- to prevent search path hijacking. All logic preserved exactly.
-- ============================================================

-- Shared version auto-increment and timestamp update function.
CREATE OR REPLACE FUNCTION update_version_and_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = OLD.version + 1;
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Auth trigger: populates public.users, user_settings, and
-- user_subscriptions when a new user signs in via Supabase Auth.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, display_name, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_subscriptions (
    user_id,
    plan_tier,
    status,
    trial_start_date,
    trial_end_date
  )
  VALUES (
    NEW.id,
    'free',
    'trialing',
    NOW(),
    NOW() + INTERVAL '1 month'
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Balance trigger: maintains expense_bank_accounts.current_balance_cents
-- when expense_transactions are inserted, updated, or deleted.
CREATE OR REPLACE FUNCTION update_bank_account_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    -- Physical DELETE of an active record: subtract from account
    IF OLD.deleted_at IS NULL THEN
      UPDATE expense_bank_accounts
        SET current_balance_cents = current_balance_cents - OLD.amount_cents
        WHERE id = OLD.account_id;
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- INSERT of an active record: add to account
    IF NEW.deleted_at IS NULL THEN
      UPDATE expense_bank_accounts
        SET current_balance_cents = current_balance_cents + NEW.amount_cents
        WHERE id = NEW.account_id;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Soft-delete: was active, now tombstoned → subtract OLD amount
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
      UPDATE expense_bank_accounts
        SET current_balance_cents = current_balance_cents - OLD.amount_cents
        WHERE id = OLD.account_id;

    -- Restore: was tombstoned, now active → add NEW amount
    ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
      UPDATE expense_bank_accounts
        SET current_balance_cents = current_balance_cents + NEW.amount_cents
        WHERE id = NEW.account_id;

    -- Update while both tombstoned → no-op
    ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NOT NULL THEN
      -- No balance change
      NULL;

    -- Update while active: adjust delta (handles amount and account changes)
    ELSE
      IF OLD.account_id = NEW.account_id THEN
        -- Same account: adjust by delta
        UPDATE expense_bank_accounts
          SET current_balance_cents = current_balance_cents + (NEW.amount_cents - OLD.amount_cents)
          WHERE id = NEW.account_id;
      ELSE
        -- Different account: subtract from old, add to new
        UPDATE expense_bank_accounts
          SET current_balance_cents = current_balance_cents - OLD.amount_cents
          WHERE id = OLD.account_id;
        UPDATE expense_bank_accounts
          SET current_balance_cents = current_balance_cents + NEW.amount_cents
          WHERE id = NEW.account_id;
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Polymorphic FK validation for expense_transaction_hashtags.
CREATE OR REPLACE FUNCTION validate_transaction_hashtag_fk()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.transaction_source = 'ledger' THEN
    IF NOT EXISTS (SELECT 1 FROM expense_transactions WHERE id = NEW.transaction_id) THEN
      RAISE EXCEPTION 'transaction_id % does not exist in expense_transactions', NEW.transaction_id;
    END IF;
  ELSIF NEW.transaction_source = 'inbox' THEN
    IF NOT EXISTS (SELECT 1 FROM expense_transaction_inbox WHERE id = NEW.transaction_id) THEN
      RAISE EXCEPTION 'transaction_id % does not exist in expense_transaction_inbox', NEW.transaction_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;
