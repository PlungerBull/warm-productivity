-- Migration: Triggers, RLS, Indexes, Views
-- All cross-cutting concerns applied after all tables exist.

-- ============================================================
-- TRIGGER FUNCTIONS
-- ============================================================

-- Shared version auto-increment and timestamp update function.
-- Used by all mutable tables.
CREATE OR REPLACE FUNCTION update_version_and_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = OLD.version + 1;
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
$$ LANGUAGE plpgsql;

-- Polymorphic FK validation for expense_transaction_hashtags.
-- transaction_id points to expense_transactions when transaction_source = 'ledger',
-- or expense_transaction_inbox when transaction_source = 'inbox'.
-- PostgreSQL cannot express conditional FKs as constraints, so a trigger enforces this.
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_expense_transaction_hashtags_fk_check
  BEFORE INSERT OR UPDATE ON expense_transaction_hashtags
  FOR EACH ROW EXECUTE FUNCTION validate_transaction_hashtag_fk();

-- ============================================================
-- VERSION TRIGGERS — all 22 mutable tables
-- ============================================================

-- Shared tables (entity_links, user_subscriptions)
CREATE TRIGGER trg_entity_links_version
  BEFORE UPDATE ON entity_links
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_user_subscriptions_version
  BEFORE UPDATE ON user_subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

-- Expense tables (9 tables)
CREATE TRIGGER trg_expense_bank_accounts_version
  BEFORE UPDATE ON expense_bank_accounts
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_expense_categories_version
  BEFORE UPDATE ON expense_categories
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_expense_hashtags_version
  BEFORE UPDATE ON expense_hashtags
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_expense_reconciliations_version
  BEFORE UPDATE ON expense_reconciliations
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_expense_transaction_inbox_version
  BEFORE UPDATE ON expense_transaction_inbox
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_expense_transactions_version
  BEFORE UPDATE ON expense_transactions
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_expense_budgets_version
  BEFORE UPDATE ON expense_budgets
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_expense_transaction_hashtags_version
  BEFORE UPDATE ON expense_transaction_hashtags
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_transaction_shares_version
  BEFORE UPDATE ON transaction_shares
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

-- Notes tables (4 tables)
CREATE TRIGGER trg_note_notebooks_version
  BEFORE UPDATE ON note_notebooks
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_note_entries_version
  BEFORE UPDATE ON note_entries
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_note_hashtags_version
  BEFORE UPDATE ON note_hashtags
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_note_entry_hashtags_version
  BEFORE UPDATE ON note_entry_hashtags
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

-- To-Do tables (7 tables)
CREATE TRIGGER trg_todo_categories_version
  BEFORE UPDATE ON todo_categories
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_todo_tasks_version
  BEFORE UPDATE ON todo_tasks
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_todo_recurrence_rules_version
  BEFORE UPDATE ON todo_recurrence_rules
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_todo_hashtags_version
  BEFORE UPDATE ON todo_hashtags
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_todo_task_hashtags_version
  BEFORE UPDATE ON todo_task_hashtags
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_todo_category_members_version
  BEFORE UPDATE ON todo_category_members
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

CREATE TRIGGER trg_streak_completions_version
  BEFORE UPDATE ON streak_completions
  FOR EACH ROW EXECUTE FUNCTION update_version_and_timestamp();

-- ============================================================
-- AUTH TRIGGER — fires on auth.users INSERT
-- ============================================================

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================
-- BALANCE TRIGGER — fires on expense_transactions changes
-- ============================================================

CREATE TRIGGER trg_expense_transactions_balance
  AFTER INSERT OR UPDATE OR DELETE ON expense_transactions
  FOR EACH ROW EXECUTE FUNCTION update_bank_account_balance();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- Standard 3-policy pattern for all per-user tables (22 tables).
-- Each table gets: SELECT, INSERT, UPDATE policies scoped to auth.uid().

-- Helper: enable RLS and create standard policies for a per-user table
-- (PostgreSQL doesn't support parameterized DDL, so each is explicit.)

-- --- user_settings ---
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON user_settings
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON user_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON user_settings
  FOR UPDATE USING (auth.uid() = user_id);

-- --- entity_links ---
ALTER TABLE entity_links ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON entity_links
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON entity_links
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON entity_links
  FOR UPDATE USING (auth.uid() = user_id);

-- --- user_subscriptions ---
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON user_subscriptions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON user_subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON user_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

-- --- activity_log (append-only: SELECT + INSERT only, no UPDATE) ---
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON activity_log
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON activity_log
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- --- expense_bank_accounts ---
ALTER TABLE expense_bank_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON expense_bank_accounts
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON expense_bank_accounts
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON expense_bank_accounts
  FOR UPDATE USING (auth.uid() = user_id);

-- --- expense_categories ---
ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON expense_categories
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON expense_categories
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON expense_categories
  FOR UPDATE USING (auth.uid() = user_id);

-- --- expense_hashtags ---
ALTER TABLE expense_hashtags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON expense_hashtags
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON expense_hashtags
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON expense_hashtags
  FOR UPDATE USING (auth.uid() = user_id);

-- --- expense_reconciliations ---
ALTER TABLE expense_reconciliations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON expense_reconciliations
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON expense_reconciliations
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON expense_reconciliations
  FOR UPDATE USING (auth.uid() = user_id);

-- --- expense_transaction_inbox ---
ALTER TABLE expense_transaction_inbox ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON expense_transaction_inbox
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON expense_transaction_inbox
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON expense_transaction_inbox
  FOR UPDATE USING (auth.uid() = user_id);

-- --- expense_transactions ---
ALTER TABLE expense_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON expense_transactions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON expense_transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON expense_transactions
  FOR UPDATE USING (auth.uid() = user_id);

-- Additional shared-expense policy: receivers can read transactions shared with them
CREATE POLICY "Receivers can read shared transactions" ON expense_transactions
  FOR SELECT USING (
    id IN (
      SELECT transaction_id FROM transaction_shares
      WHERE user_id = auth.uid() AND deleted_at IS NULL
    )
  );

-- --- expense_budgets ---
ALTER TABLE expense_budgets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON expense_budgets
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON expense_budgets
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON expense_budgets
  FOR UPDATE USING (auth.uid() = user_id);

-- --- expense_transaction_hashtags ---
ALTER TABLE expense_transaction_hashtags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON expense_transaction_hashtags
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON expense_transaction_hashtags
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON expense_transaction_hashtags
  FOR UPDATE USING (auth.uid() = user_id);

-- --- transaction_shares ---
-- user_id on transaction_shares is the RECEIVER, not the originator.
-- Receiver policies: read and update their own share rows.
-- Originator policies: read and insert shares on their own transactions.
ALTER TABLE transaction_shares ENABLE ROW LEVEL SECURITY;

-- Receiver can read their own shares
CREATE POLICY "Receivers can read own shares" ON transaction_shares
  FOR SELECT USING (auth.uid() = user_id);

-- Receiver can update their own shares (category, confirmation flag)
CREATE POLICY "Receivers can update own shares" ON transaction_shares
  FOR UPDATE USING (auth.uid() = user_id);

-- Originator can read shares on transactions they own
CREATE POLICY "Originators can read shares on own transactions" ON transaction_shares
  FOR SELECT USING (
    transaction_id IN (
      SELECT id FROM expense_transactions
      WHERE user_id = auth.uid()
    )
  );

-- Originator can create shares on transactions they own
CREATE POLICY "Originators can insert shares on own transactions" ON transaction_shares
  FOR INSERT WITH CHECK (
    transaction_id IN (
      SELECT id FROM expense_transactions
      WHERE user_id = auth.uid()
    )
  );

-- Originator can update shares on transactions they own (confirmation reset)
CREATE POLICY "Originators can update shares on own transactions" ON transaction_shares
  FOR UPDATE USING (
    transaction_id IN (
      SELECT id FROM expense_transactions
      WHERE user_id = auth.uid()
    )
  );

-- --- note_notebooks ---
ALTER TABLE note_notebooks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON note_notebooks
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON note_notebooks
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON note_notebooks
  FOR UPDATE USING (auth.uid() = user_id);

-- --- note_entries ---
ALTER TABLE note_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON note_entries
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON note_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON note_entries
  FOR UPDATE USING (auth.uid() = user_id);

-- --- note_hashtags ---
ALTER TABLE note_hashtags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON note_hashtags
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON note_hashtags
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON note_hashtags
  FOR UPDATE USING (auth.uid() = user_id);

-- --- note_entry_hashtags ---
ALTER TABLE note_entry_hashtags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON note_entry_hashtags
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON note_entry_hashtags
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON note_entry_hashtags
  FOR UPDATE USING (auth.uid() = user_id);

-- --- todo_categories ---
ALTER TABLE todo_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON todo_categories
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON todo_categories
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON todo_categories
  FOR UPDATE USING (auth.uid() = user_id);

-- --- todo_tasks ---
ALTER TABLE todo_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON todo_tasks
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON todo_tasks
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON todo_tasks
  FOR UPDATE USING (auth.uid() = user_id);

-- --- todo_recurrence_rules ---
ALTER TABLE todo_recurrence_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON todo_recurrence_rules
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON todo_recurrence_rules
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON todo_recurrence_rules
  FOR UPDATE USING (auth.uid() = user_id);

-- --- todo_hashtags ---
ALTER TABLE todo_hashtags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON todo_hashtags
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON todo_hashtags
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON todo_hashtags
  FOR UPDATE USING (auth.uid() = user_id);

-- --- todo_task_hashtags ---
ALTER TABLE todo_task_hashtags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON todo_task_hashtags
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON todo_task_hashtags
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON todo_task_hashtags
  FOR UPDATE USING (auth.uid() = user_id);

-- --- todo_category_members ---
ALTER TABLE todo_category_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON todo_category_members
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON todo_category_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON todo_category_members
  FOR UPDATE USING (auth.uid() = user_id);

-- --- streak_completions ---
ALTER TABLE streak_completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON streak_completions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON streak_completions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON streak_completions
  FOR UPDATE USING (auth.uid() = user_id);

-- --- global_currencies (read-only public access, no user_id) ---
-- No RLS — readable by all authenticated users.

-- --- exchange_rates (read-only public access, no user_id) ---
-- No RLS — readable by all authenticated users.

-- ============================================================
-- INDEXES
-- ============================================================

-- --------------------------------------------------------
-- Universal 3-index set on all per-user tables
-- (user_id, user_id+deleted_at, user_id+version)
-- --------------------------------------------------------

-- entity_links
CREATE INDEX IF NOT EXISTS idx_entity_links_user_id
  ON entity_links (user_id);
CREATE INDEX IF NOT EXISTS idx_entity_links_user_deleted
  ON entity_links (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_entity_links_user_version
  ON entity_links (user_id, version);

-- user_subscriptions
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id
  ON user_subscriptions (user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_deleted
  ON user_subscriptions (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_version
  ON user_subscriptions (user_id, version);

-- activity_log
CREATE INDEX IF NOT EXISTS idx_activity_log_user_id
  ON activity_log (user_id);

-- expense_bank_accounts
CREATE INDEX IF NOT EXISTS idx_expense_bank_accounts_user_id
  ON expense_bank_accounts (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_bank_accounts_user_deleted
  ON expense_bank_accounts (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_expense_bank_accounts_user_version
  ON expense_bank_accounts (user_id, version);

-- expense_categories
CREATE INDEX IF NOT EXISTS idx_expense_categories_user_id
  ON expense_categories (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_categories_user_deleted
  ON expense_categories (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_expense_categories_user_version
  ON expense_categories (user_id, version);

-- expense_hashtags
CREATE INDEX IF NOT EXISTS idx_expense_hashtags_user_id
  ON expense_hashtags (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_hashtags_user_deleted
  ON expense_hashtags (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_expense_hashtags_user_version
  ON expense_hashtags (user_id, version);

-- expense_reconciliations
CREATE INDEX IF NOT EXISTS idx_expense_reconciliations_user_id
  ON expense_reconciliations (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_reconciliations_user_deleted
  ON expense_reconciliations (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_expense_reconciliations_user_version
  ON expense_reconciliations (user_id, version);

-- expense_transaction_inbox
CREATE INDEX IF NOT EXISTS idx_expense_transaction_inbox_user_id
  ON expense_transaction_inbox (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_transaction_inbox_user_deleted
  ON expense_transaction_inbox (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_expense_transaction_inbox_user_version
  ON expense_transaction_inbox (user_id, version);

-- expense_transactions
CREATE INDEX IF NOT EXISTS idx_expense_transactions_user_id
  ON expense_transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_transactions_user_deleted
  ON expense_transactions (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_expense_transactions_user_version
  ON expense_transactions (user_id, version);

-- expense_budgets
CREATE INDEX IF NOT EXISTS idx_expense_budgets_user_id
  ON expense_budgets (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_budgets_user_deleted
  ON expense_budgets (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_expense_budgets_user_version
  ON expense_budgets (user_id, version);

-- expense_transaction_hashtags
CREATE INDEX IF NOT EXISTS idx_expense_transaction_hashtags_user_id
  ON expense_transaction_hashtags (user_id);
CREATE INDEX IF NOT EXISTS idx_expense_transaction_hashtags_user_deleted
  ON expense_transaction_hashtags (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_expense_transaction_hashtags_user_version
  ON expense_transaction_hashtags (user_id, version);

-- transaction_shares
CREATE INDEX IF NOT EXISTS idx_transaction_shares_user_id
  ON transaction_shares (user_id);
CREATE INDEX IF NOT EXISTS idx_transaction_shares_user_deleted
  ON transaction_shares (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_transaction_shares_user_version
  ON transaction_shares (user_id, version);

-- note_notebooks
CREATE INDEX IF NOT EXISTS idx_note_notebooks_user_id
  ON note_notebooks (user_id);
CREATE INDEX IF NOT EXISTS idx_note_notebooks_user_deleted
  ON note_notebooks (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_note_notebooks_user_version
  ON note_notebooks (user_id, version);

-- note_entries
CREATE INDEX IF NOT EXISTS idx_note_entries_user_id
  ON note_entries (user_id);
CREATE INDEX IF NOT EXISTS idx_note_entries_user_deleted
  ON note_entries (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_note_entries_user_version
  ON note_entries (user_id, version);

-- note_hashtags
CREATE INDEX IF NOT EXISTS idx_note_hashtags_user_id
  ON note_hashtags (user_id);
CREATE INDEX IF NOT EXISTS idx_note_hashtags_user_deleted
  ON note_hashtags (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_note_hashtags_user_version
  ON note_hashtags (user_id, version);

-- note_entry_hashtags
CREATE INDEX IF NOT EXISTS idx_note_entry_hashtags_user_id
  ON note_entry_hashtags (user_id);
CREATE INDEX IF NOT EXISTS idx_note_entry_hashtags_user_deleted
  ON note_entry_hashtags (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_note_entry_hashtags_user_version
  ON note_entry_hashtags (user_id, version);

-- todo_categories
CREATE INDEX IF NOT EXISTS idx_todo_categories_user_id
  ON todo_categories (user_id);
CREATE INDEX IF NOT EXISTS idx_todo_categories_user_deleted
  ON todo_categories (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_todo_categories_user_version
  ON todo_categories (user_id, version);

-- todo_tasks
CREATE INDEX IF NOT EXISTS idx_todo_tasks_user_id
  ON todo_tasks (user_id);
CREATE INDEX IF NOT EXISTS idx_todo_tasks_user_deleted
  ON todo_tasks (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_todo_tasks_user_version
  ON todo_tasks (user_id, version);

-- todo_recurrence_rules
CREATE INDEX IF NOT EXISTS idx_todo_recurrence_rules_user_id
  ON todo_recurrence_rules (user_id);
CREATE INDEX IF NOT EXISTS idx_todo_recurrence_rules_user_deleted
  ON todo_recurrence_rules (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_todo_recurrence_rules_user_version
  ON todo_recurrence_rules (user_id, version);

-- todo_hashtags
CREATE INDEX IF NOT EXISTS idx_todo_hashtags_user_id
  ON todo_hashtags (user_id);
CREATE INDEX IF NOT EXISTS idx_todo_hashtags_user_deleted
  ON todo_hashtags (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_todo_hashtags_user_version
  ON todo_hashtags (user_id, version);

-- todo_task_hashtags
CREATE INDEX IF NOT EXISTS idx_todo_task_hashtags_user_id
  ON todo_task_hashtags (user_id);
CREATE INDEX IF NOT EXISTS idx_todo_task_hashtags_user_deleted
  ON todo_task_hashtags (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_todo_task_hashtags_user_version
  ON todo_task_hashtags (user_id, version);

-- todo_category_members
CREATE INDEX IF NOT EXISTS idx_todo_category_members_user_id
  ON todo_category_members (user_id);
CREATE INDEX IF NOT EXISTS idx_todo_category_members_user_deleted
  ON todo_category_members (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_todo_category_members_user_version
  ON todo_category_members (user_id, version);

-- streak_completions
CREATE INDEX IF NOT EXISTS idx_streak_completions_user_id
  ON streak_completions (user_id);
CREATE INDEX IF NOT EXISTS idx_streak_completions_user_deleted
  ON streak_completions (user_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_streak_completions_user_version
  ON streak_completions (user_id, version);

-- --------------------------------------------------------
-- Table-specific indexes (15 indexes per architecture doc)
-- --------------------------------------------------------

-- Transaction list sorted by date
CREATE INDEX IF NOT EXISTS idx_expense_transactions_user_date
  ON expense_transactions (user_id, date DESC);

-- Sidebar balance aggregation per account
CREATE INDEX IF NOT EXISTS idx_expense_transactions_account_id
  ON expense_transactions (account_id);

-- Sidebar balance aggregation per category
CREATE INDEX IF NOT EXISTS idx_expense_transactions_category_id
  ON expense_transactions (category_id);

-- Fetching all transactions in a reconciliation batch
CREATE INDEX IF NOT EXISTS idx_expense_transactions_reconciliation_id
  ON expense_transactions (reconciliation_id);

-- Inbox list sorted by creation date
CREATE INDEX IF NOT EXISTS idx_expense_transaction_inbox_user_created
  ON expense_transaction_inbox (user_id, created_at DESC);

-- Today/Upcoming tab queries filter by date
CREATE INDEX IF NOT EXISTS idx_todo_tasks_user_due_date
  ON todo_tasks (user_id, due_date);

-- Filtering tasks by category
CREATE INDEX IF NOT EXISTS idx_todo_tasks_user_category
  ON todo_tasks (user_id, category_id);

-- Fetching subtasks for a given parent
CREATE INDEX IF NOT EXISTS idx_todo_tasks_parent_task_id
  ON todo_tasks (parent_task_id);

-- Composite for Today/Upcoming tab (non-completed, date-filtered)
CREATE INDEX IF NOT EXISTS idx_todo_tasks_user_completed_due
  ON todo_tasks (user_id, is_completed, due_date);

-- Fetching notes in a notebook
CREATE INDEX IF NOT EXISTS idx_note_entries_user_notebook
  ON note_entries (user_id, notebook_id);

-- Fetching pinned notes
CREATE INDEX IF NOT EXISTS idx_note_entries_user_pinned
  ON note_entries (user_id, is_pinned);

-- Looking up all links from a given source entity
CREATE INDEX IF NOT EXISTS idx_entity_links_source
  ON entity_links (source_id, source_type);

-- Looking up all links pointing to a given entity
CREATE INDEX IF NOT EXISTS idx_entity_links_target
  ON entity_links (target_id, target_type);

-- Junction table FK lookups (joining hashtags back to their parent entities)
CREATE INDEX IF NOT EXISTS idx_expense_transaction_hashtags_transaction_id
  ON expense_transaction_hashtags (transaction_id);

CREATE INDEX IF NOT EXISTS idx_note_entry_hashtags_note_id
  ON note_entry_hashtags (note_id);

CREATE INDEX IF NOT EXISTS idx_todo_task_hashtags_task_id
  ON todo_task_hashtags (task_id);

-- Subscription status queries (feature gating checks)
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_status
  ON user_subscriptions (user_id, status);

-- Activity log timeline (sorted display per user)
CREATE INDEX IF NOT EXISTS idx_activity_log_user_timestamp
  ON activity_log (user_id, timestamp DESC);

-- exchange_rates (base_currency, target_currency, rate_date)
-- Already covered by UNIQUE constraint uq_exchange_rates_pair_date — no separate index needed.

-- Finding all categories a user is a member of
-- todo_category_members (user_id) — already covered by idx_todo_category_members_user_id above.
-- The UNIQUE constraint on (category_id, user_id) also creates an index automatically.

-- ============================================================
-- VIEWS
-- ============================================================

-- Joins inbox items with account, category, and linked task details
CREATE OR REPLACE VIEW expense_transaction_inbox_view AS
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
CREATE OR REPLACE VIEW expense_categories_with_counts AS
SELECT
  c.*,
  COUNT(t.id) FILTER (WHERE t.deleted_at IS NULL) AS transaction_count
FROM expense_categories c
LEFT JOIN expense_transactions t ON c.id = t.category_id
WHERE c.deleted_at IS NULL
GROUP BY c.id;

-- Notes joined with their notebook details
CREATE OR REPLACE VIEW note_entries_with_notebooks AS
SELECT
  n.*,
  nb.name AS notebook_name,
  nb.color AS notebook_color
FROM note_entries n
LEFT JOIN note_notebooks nb ON n.notebook_id = nb.id
WHERE n.deleted_at IS NULL;
