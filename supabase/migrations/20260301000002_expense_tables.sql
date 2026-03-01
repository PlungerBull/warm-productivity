-- Migration: Expense Tracker Tables
-- All Expense Tracker tables in FK dependency order.
-- Tables: expense_bank_accounts, expense_categories, expense_hashtags,
--         expense_reconciliations, expense_transaction_inbox,
--         expense_transactions, expense_budgets,
--         expense_transaction_hashtags, transaction_shares

-- ============================================================
-- expense_bank_accounts
-- ============================================================

CREATE TABLE IF NOT EXISTS expense_bank_accounts (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name                  TEXT NOT NULL,
  currency_code         TEXT NOT NULL DEFAULT 'USD' REFERENCES global_currencies(code),
  is_person             BOOLEAN NOT NULL DEFAULT false,
  linked_user_id        UUID REFERENCES users(id) ON DELETE SET NULL,
  color                 TEXT NOT NULL DEFAULT '#3b82f6',
  is_visible            BOOLEAN NOT NULL DEFAULT true,
  current_balance_cents BIGINT NOT NULL DEFAULT 0,
  is_archived           BOOLEAN NOT NULL DEFAULT false,
  sort_order            INTEGER NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  version               INTEGER NOT NULL DEFAULT 1,
  deleted_at            TIMESTAMPTZ,
  synced_at             TIMESTAMPTZ,

  CONSTRAINT uq_expense_bank_accounts_user_name_currency
    UNIQUE (user_id, name, currency_code)
);

-- ============================================================
-- expense_categories
-- ============================================================

CREATE TABLE IF NOT EXISTS expense_categories (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  category_type expense_category_type NOT NULL DEFAULT 'expense',
  color         TEXT NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  version       INTEGER NOT NULL DEFAULT 1,
  deleted_at    TIMESTAMPTZ,
  synced_at     TIMESTAMPTZ,

  CONSTRAINT uq_expense_categories_user_name
    UNIQUE (user_id, name)
);

-- ============================================================
-- expense_hashtags
-- ============================================================

CREATE TABLE IF NOT EXISTS expense_hashtags (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version    INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ,
  synced_at  TIMESTAMPTZ,

  CONSTRAINT uq_expense_hashtags_user_name
    UNIQUE (user_id, name)
);

-- ============================================================
-- expense_reconciliations
-- Created before expense_transactions since transactions FK to it.
-- ============================================================

CREATE TABLE IF NOT EXISTS expense_reconciliations (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  account_id             UUID NOT NULL REFERENCES expense_bank_accounts(id) ON DELETE CASCADE,
  name                   TEXT NOT NULL,
  date_start             TIMESTAMPTZ,
  date_end               TIMESTAMPTZ,
  status                 reconciliation_status NOT NULL DEFAULT 'draft',
  beginning_balance_cents BIGINT NOT NULL DEFAULT 0,
  ending_balance_cents   BIGINT NOT NULL DEFAULT 0,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  version                INTEGER NOT NULL DEFAULT 1,
  deleted_at             TIMESTAMPTZ,
  synced_at              TIMESTAMPTZ
);

-- ============================================================
-- expense_transaction_inbox
-- Note: linked_task_id column created as nullable UUID with no FK.
-- The FK to todo_tasks is added in migration file 5 after todo_tasks exists.
-- ============================================================

CREATE TABLE IF NOT EXISTS expense_transaction_inbox (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title             TEXT NOT NULL DEFAULT 'UNTITLED',
  amount_cents      BIGINT,
  date              TIMESTAMPTZ DEFAULT now(),
  account_id        UUID REFERENCES expense_bank_accounts(id) ON DELETE SET NULL,
  category_id       UUID REFERENCES expense_categories(id) ON DELETE SET NULL,
  exchange_rate     NUMERIC DEFAULT 1.0,
  is_recurring      BOOLEAN NOT NULL DEFAULT false,
  linked_task_id    UUID,
  source_text       TEXT,
  receipt_photo_url TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  version           INTEGER NOT NULL DEFAULT 1,
  deleted_at        TIMESTAMPTZ,
  synced_at         TIMESTAMPTZ
);

-- ============================================================
-- expense_transactions
-- ============================================================

CREATE TABLE IF NOT EXISTS expense_transactions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title             TEXT NOT NULL,
  amount_cents      BIGINT NOT NULL,
  amount_home_cents BIGINT,
  date              TIMESTAMPTZ NOT NULL DEFAULT now(),
  account_id        UUID NOT NULL REFERENCES expense_bank_accounts(id) ON DELETE CASCADE,
  category_id       UUID NOT NULL REFERENCES expense_categories(id) ON DELETE CASCADE,
  exchange_rate     NUMERIC NOT NULL DEFAULT 1.0,
  transfer_id       UUID,
  inbox_id          UUID REFERENCES expense_transaction_inbox(id) ON DELETE SET NULL,
  reconciliation_id UUID REFERENCES expense_reconciliations(id) ON DELETE SET NULL,
  cleared           BOOLEAN NOT NULL DEFAULT false,
  source_text       TEXT,
  receipt_photo_url TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  version           INTEGER NOT NULL DEFAULT 1,
  deleted_at        TIMESTAMPTZ,
  synced_at         TIMESTAMPTZ
);

-- ============================================================
-- expense_budgets
-- ============================================================

CREATE TABLE IF NOT EXISTS expense_budgets (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id  UUID NOT NULL REFERENCES expense_categories(id) ON DELETE CASCADE,
  amount_cents BIGINT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  version      INTEGER NOT NULL DEFAULT 1,
  deleted_at   TIMESTAMPTZ,
  synced_at    TIMESTAMPTZ,

  CONSTRAINT uq_expense_budgets_user_category
    UNIQUE (user_id, category_id)
);

-- ============================================================
-- expense_transaction_hashtags
-- Note: transaction_id has no inline FK because it's polymorphic —
-- it references expense_transactions or expense_transaction_inbox
-- depending on transaction_source. Enforced by a validation trigger
-- in the triggers migration file.
-- ============================================================

CREATE TABLE IF NOT EXISTS expense_transaction_hashtags (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id     UUID NOT NULL,
  transaction_source transaction_source_type NOT NULL,
  hashtag_id         UUID NOT NULL REFERENCES expense_hashtags(id) ON DELETE CASCADE,
  user_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  version            INTEGER NOT NULL DEFAULT 1,
  deleted_at         TIMESTAMPTZ,
  synced_at          TIMESTAMPTZ,

  CONSTRAINT uq_expense_transaction_hashtags_txn_hashtag
    UNIQUE (transaction_id, hashtag_id)
);

-- ============================================================
-- transaction_shares
-- Cross-user shared expenses.
-- ============================================================

CREATE TABLE IF NOT EXISTS transaction_shares (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id        UUID NOT NULL REFERENCES expense_transactions(id) ON DELETE CASCADE,
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id           UUID REFERENCES expense_categories(id) ON DELETE SET NULL,
  originator_confirmed  BOOLEAN NOT NULL DEFAULT false,
  receiver_confirmed    BOOLEAN NOT NULL DEFAULT false,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  version               INTEGER NOT NULL DEFAULT 1,
  deleted_at            TIMESTAMPTZ,
  synced_at             TIMESTAMPTZ,

  CONSTRAINT uq_transaction_shares_txn_user
    UNIQUE (transaction_id, user_id)
);
