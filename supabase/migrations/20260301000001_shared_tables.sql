-- Migration: Shared Tables
-- Foundation tables that all three apps depend on.
-- Tables: users, user_settings, global_currencies, exchange_rates,
--         entity_links, user_subscriptions, activity_log

-- ============================================================
-- users
-- Exception: managed by Supabase Auth. No version/deleted_at/synced_at.
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY,
  email       TEXT,
  display_name TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- user_settings
-- Single-row config per user. No is_archived, no sort_order (artifacts removed).
-- ============================================================

CREATE TABLE IF NOT EXISTS user_settings (
  user_id                           UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme                             TEXT NOT NULL DEFAULT 'system',
  start_of_week                     INTEGER NOT NULL DEFAULT 0,
  main_currency                     TEXT NOT NULL DEFAULT 'USD',
  transaction_sort_preference       TEXT NOT NULL DEFAULT 'date',
  budget_enabled                    BOOLEAN NOT NULL DEFAULT false,
  linked_notes_visible_in_notes_app BOOLEAN NOT NULL DEFAULT true,
  sidebar_show_bank_accounts        BOOLEAN NOT NULL DEFAULT true,
  sidebar_show_people               BOOLEAN NOT NULL DEFAULT true,
  sidebar_show_categories           BOOLEAN NOT NULL DEFAULT true,
  display_timezone                  TEXT NOT NULL DEFAULT 'UTC',
  todo_tab_show_inbox               BOOLEAN NOT NULL DEFAULT true,
  todo_tab_show_today               BOOLEAN NOT NULL DEFAULT true,
  todo_tab_show_upcoming            BOOLEAN NOT NULL DEFAULT true,
  todo_tab_show_browse              BOOLEAN NOT NULL DEFAULT true,
  expense_tab_show_budgeting        BOOLEAN NOT NULL DEFAULT true,
  expense_tab_show_reconciliations  BOOLEAN NOT NULL DEFAULT true,
  created_at                        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- FK to global_currencies added after that table is created
-- (see ALTER TABLE below)

-- ============================================================
-- global_currencies
-- Exception: static lookup table. Text PK, no sync fields.
-- ============================================================

CREATE TABLE IF NOT EXISTS global_currencies (
  code   TEXT PRIMARY KEY,
  name   TEXT NOT NULL,
  symbol TEXT NOT NULL,
  flag   TEXT
);

-- Now add the FK from user_settings.main_currency → global_currencies.code
ALTER TABLE user_settings
  ADD CONSTRAINT fk_user_settings_main_currency
  FOREIGN KEY (main_currency) REFERENCES global_currencies(code);

-- ============================================================
-- exchange_rates
-- Exception: append-only global reference table. No user_id, no RLS,
-- no version/deleted_at/synced_at. No is_archived, no sort_order (artifacts removed).
-- ============================================================

CREATE TABLE IF NOT EXISTS exchange_rates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  base_currency   TEXT NOT NULL REFERENCES global_currencies(code),
  target_currency TEXT NOT NULL REFERENCES global_currencies(code),
  rate            NUMERIC NOT NULL,
  rate_date       DATE NOT NULL,
  fetched_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_exchange_rates_pair_date
    UNIQUE (base_currency, target_currency, rate_date)
);

-- ============================================================
-- entity_links
-- Cross-app glue table. Mutable with full sync fields.
-- No is_archived, no sort_order (artifacts removed).
-- ============================================================

CREATE TABLE IF NOT EXISTS entity_links (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_type  entity_source_type NOT NULL,
  source_id    UUID NOT NULL,
  target_type  entity_source_type NOT NULL,
  target_id    UUID NOT NULL,
  link_context entity_link_context NOT NULL,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  version      INTEGER NOT NULL DEFAULT 1,
  deleted_at   TIMESTAMPTZ,
  synced_at    TIMESTAMPTZ
);

-- ============================================================
-- user_subscriptions
-- One row per user, mutable with sync fields.
-- ============================================================

CREATE TABLE IF NOT EXISTS user_subscriptions (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id               TEXT,
  plan_tier                plan_tier NOT NULL DEFAULT 'free',
  status                   subscription_status NOT NULL DEFAULT 'trialing',
  auto_renew_enabled       BOOLEAN NOT NULL DEFAULT true,
  trial_start_date         TIMESTAMPTZ,
  trial_end_date           TIMESTAMPTZ,
  current_period_start     TIMESTAMPTZ,
  current_period_end       TIMESTAMPTZ,
  grace_period_end         TIMESTAMPTZ,
  cancellation_date        TIMESTAMPTZ,
  original_transaction_id  TEXT,
  environment              subscription_environment NOT NULL DEFAULT 'production',
  platform                 TEXT NOT NULL DEFAULT 'ios',
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  version                  INTEGER NOT NULL DEFAULT 1,
  deleted_at               TIMESTAMPTZ,
  synced_at                TIMESTAMPTZ,

  CONSTRAINT uq_user_subscriptions_user UNIQUE (user_id)
);

-- ============================================================
-- activity_log
-- Exception: append-only audit trail. No version or deleted_at.
-- Has synced_at only.
-- ============================================================

CREATE TABLE IF NOT EXISTS activity_log (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action_type  action_type NOT NULL,
  entity_type  TEXT NOT NULL,
  entity_id    UUID NOT NULL,
  summary_text TEXT NOT NULL,
  timestamp    TIMESTAMPTZ NOT NULL DEFAULT now(),
  synced_at    TIMESTAMPTZ
);
