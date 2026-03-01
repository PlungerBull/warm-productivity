# Skill: Database Schema

**Use when:** Adding or modifying a database table, column, constraint, index, enum, trigger, or RLS policy.

**Load before using:** `warm-productivity-system-architecture.md` (full schema reference).

---

## Pre-Flight Checklist

Before writing any SQL, answer these questions:

1. **Which app owns this table?** Prefix accordingly (`expense_`, `todo_`, `note_`) or leave unprefixed for shared tables.
2. **Is this table mutable user data?** If yes, it needs the full mutable column set (see below). If it's a reference table, append-only table, or externally managed table, document the exception.
3. **Does this table need RLS?** Every table with `user_id` gets RLS. Reference tables without `user_id` (like `global_currencies`, `exchange_rates`) do not.
4. **Does a SwiftData model need to be created or updated?** Every Supabase table that syncs to the client has a corresponding SwiftData entity in `Packages/SharedModels/`.
5. **Are there foreign keys?** Verify the referenced table and column exist. Respect the sync push order (parent before child).

---

## Migration File Convention

**Location:** `supabase/migrations/`

**Naming:** `YYYYMMDDHHMMSS_description.sql` — sequential timestamp, lowercase snake_case description.

```
supabase/migrations/
  20260301000000_initial_schema.sql
  20260315120000_add_expense_hashtags.sql
```

**Rules:**
- One logical change per migration file. A new table and its indexes go in one file. An unrelated column addition goes in a separate file.
- All `CREATE` statements use `IF NOT EXISTS` for idempotency.
- All `CREATE INDEX` statements use `IF NOT EXISTS`.
- Never use `DROP` in a migration unless explicitly instructed. Schema evolution adds, never removes.
- Include clear comments at the top of the file describing what the migration does.

---

## Column Conventions

### Naming

All column names use `snake_case`. PostgreSQL convention, not Swift camelCase. Swift models map via `CodingKeys`.

### Primary Keys

Every table uses UUID primary keys generated locally:

```sql
id UUID PRIMARY KEY DEFAULT uuid_generate_v4()
```

**Exception:** `global_currencies` uses `code TEXT PRIMARY KEY` for readability.

### Required Columns — Mutable Tables

Every mutable user-data table includes these columns. No exceptions.

```sql
-- Timestamps
created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

-- Delta sync
version     INTEGER NOT NULL DEFAULT 1,

-- Soft delete (tombstone)
deleted_at  TIMESTAMPTZ,

-- Sync tracking
synced_at   TIMESTAMPTZ
```

**Also required on every per-user table:**

```sql
user_id UUID NOT NULL REFERENCES users(id)
```

### Exceptions — Tables That Skip Mutable Columns

These table types are exempt from `version`, `deleted_at`, and `synced_at`:

| Table type | Example | What it keeps | Why |
|---|---|---|---|
| Static lookup | `global_currencies` | `code` PK only | Predefined rows, never edited by users |
| Append-only reference | `exchange_rates` | `created_at`, `updated_at` | One row per currency pair per day, never edited or deleted |
| Externally managed | `users` | Supabase Auth conventions | Managed by Supabase Auth, not the app |
| Append-only audit | `activity_log` | `timestamp`, `synced_at` | Entries never edited or deleted by users |

Document any new exception in the migration file comments and in the System Architecture doc.

---

## Monetary Values

**Always store as `BIGINT` in cents.** Never use `DECIMAL`, `NUMERIC`, or `FLOAT` for monetary amounts.

```sql
amount_cents      BIGINT NOT NULL,           -- $30.50 = 3050
amount_home_cents BIGINT,                    -- cached display value in main_currency
```

`amount_home_cents` is a derived cache: `amount_cents * exchange_rate`. Not a source of truth.

---

## Enum Types

Define PostgreSQL enums as custom types. Create the type before the table that uses it.

```sql
-- Create enum type
CREATE TYPE expense_category_type AS ENUM ('income', 'expense');

-- Use in table
category_type expense_category_type NOT NULL DEFAULT 'expense'
```

**Naming:** `snake_case`, descriptive. Examples: `reconciliation_status`, `recurrence_pattern`, `action_type`.

**Existing enums (do not recreate):**
- `expense_category_type` — `'income'`, `'expense'`
- `reconciliation_status` — `'draft'`, `'completed'`
- `recurrence_pattern` — `'daily'`, `'weekly'`, `'specific_days'`, `'monthly'`, `'yearly'`
- `recurrence_anchor` — `'fixed'`, `'after_completion'`
- `subtask_mode` — `'independent'`, `'gated'`
- `action_type` — `'created'`, `'deleted'`, `'completed'`, `'modified'`
- `plan_tier` — `'free'`, `'pro'`
- `subscription_status` — `'trialing'`, `'active'`, `'grace_period'`, `'billing_retry'`, `'expired'`, `'cancelled'`, `'revoked'`
- `subscription_environment` — `'sandbox'`, `'production'`
- `streak_frequency` — `'daily'`, `'weekly'`, `'monthly'`
- `streak_goal_type` — `'achieve_all'`, `'reach_amount'`
- `streak_recording_method` — `'auto'`, `'manual'`, `'complete_all'`
- `todo_member_role` — `'owner'`, `'member'`

---

## Display Name Convention

All entities use `title` as their display name field:

```sql
title TEXT NOT NULL DEFAULT 'UNTITLED'
```

**There is no `description` column on any table.** All free-text content lives in `note_entries`, linked via `entity_links` (Universal Description Model). If you find yourself adding a `description` column, stop — use the entity_links pattern instead.

---

## Soft Deletes

**Never hard-delete mutable rows.** Always set `deleted_at`:

```sql
UPDATE some_table SET deleted_at = now() WHERE id = ?;
```

All repository read queries include `WHERE deleted_at IS NULL` by default.

Tombstone cleanup: a `pg_cron` job prunes records with `deleted_at` older than 30 days.

---

## Indexes

### Universal Indexes (every per-user table)

```sql
CREATE INDEX IF NOT EXISTS idx_{table}_user_id
  ON {table} (user_id);

CREATE INDEX IF NOT EXISTS idx_{table}_user_deleted
  ON {table} (user_id, deleted_at);

CREATE INDEX IF NOT EXISTS idx_{table}_user_version
  ON {table} (user_id, version);
```

### Table-Specific Indexes

Add indexes based on actual query patterns. Document the query pattern in a comment:

```sql
-- Supports: transaction list sorted by date
CREATE INDEX IF NOT EXISTS idx_expense_transactions_user_date
  ON expense_transactions (user_id, date DESC);
```

**Do not add indexes speculatively.** Only index columns that appear in WHERE, ORDER BY, or JOIN clauses of real queries.

UNIQUE constraints automatically create B-tree indexes — do not add a separate index for columns already covered by a UNIQUE constraint.

---

## Constraints

### Foreign Keys

Always specify `REFERENCES` with the target table and column:

```sql
account_id UUID NOT NULL REFERENCES expense_bank_accounts(id),
category_id UUID NOT NULL REFERENCES expense_categories(id),
```

Nullable foreign keys are allowed when the relationship is optional:

```sql
notebook_id UUID REFERENCES note_notebooks(id),  -- null = Inbox
```

### Unique Constraints

Name them descriptively:

```sql
CONSTRAINT uq_expense_categories_user_name UNIQUE (user_id, name)
```

### Check Constraints

Use for business rules that can be expressed at the database level:

```sql
CONSTRAINT chk_note_pinned_requires_notebook
  CHECK (notebook_id IS NOT NULL OR is_pinned = false)
```

---

## Row-Level Security (RLS)

Every table with `user_id` gets RLS enabled and three policies:

```sql
ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own data" ON {table}
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own data" ON {table}
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own data" ON {table}
  FOR UPDATE USING (auth.uid() = user_id);
```

**Tables without `user_id`** (like `global_currencies`, `exchange_rates`) do not get RLS — they are readable by all authenticated users.

**Additional policies** for cross-user features (e.g., shared expenses) are added as needed. Document them clearly.

---

## Triggers

### Version Auto-Increment

Every mutable table gets a trigger that increments `version` and updates `updated_at` on every UPDATE:

```sql
CREATE OR REPLACE FUNCTION update_version_and_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = OLD.version + 1;
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_{table}_version
  BEFORE UPDATE ON {table}
  FOR EACH ROW
  EXECUTE FUNCTION update_version_and_timestamp();
```

### Balance Trigger

`expense_bank_accounts.current_balance_cents` is maintained by a trigger on `expense_transactions`. See the System Architecture doc for the full lifecycle matrix (INSERT, soft-delete, restore, update, physical DELETE).

---

## Database Views

Use views for common read patterns that join multiple tables:

```sql
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
```

**Naming:** `{table}_view` or descriptive name like `expense_categories_with_counts`.

---

## Sync Push Order (Foreign Key Dependencies)

When the sync engine pushes creates/updates, it follows this order to satisfy foreign key constraints:

1. `users` / `user_settings`
2. `global_currencies`
3. `expense_bank_accounts`
4. `expense_categories` / `todo_categories` / `note_notebooks`
5. `expense_hashtags` / `todo_hashtags` / `note_hashtags`
6. `expense_budgets`
7. `expense_transactions` / `expense_transaction_inbox`
8. `todo_tasks`
9. `todo_recurrence_rules`
10. `note_entries`
11. Junction tables (`expense_transaction_hashtags`, `todo_task_hashtags`, `note_entry_hashtags`)
12. `entity_links`
13. `streak_completions`
14. `expense_reconciliations`
15. `activity_log`

Deletes go in reverse order (PRUNE phase before PLANT phase).

---

## SwiftData Model Correspondence

Every Supabase table that syncs to the client has a SwiftData `@Model` in `Packages/SharedModels/`. The Swift model:

- Uses `camelCase` property names
- Maps to `snake_case` DB columns via `CodingKeys`
- Mirrors nullable/non-null exactly
- Uses `Int64` for `BIGINT` (cents), `Int` for `INTEGER` (version, sort_order)
- Uses `Date` for `TIMESTAMPTZ`
- Uses `UUID` for UUID columns
- Uses Swift `enum` for PostgreSQL enums

**When you add or modify a column in SQL, update the corresponding SwiftData model.** When you add a new table, create a new SwiftData model.

---

## Post-Change Checklist

After writing a migration:

- [ ] Migration file is named with correct timestamp format
- [ ] All `CREATE` statements use `IF NOT EXISTS`
- [ ] Mutable table has all required columns (created_at, updated_at, version, deleted_at, synced_at)
- [ ] user_id column references users(id)
- [ ] Universal indexes added (user_id, user_id+deleted_at, user_id+version)
- [ ] Query-specific indexes added with comments explaining the query pattern
- [ ] RLS enabled with three standard policies
- [ ] Version auto-increment trigger created
- [ ] Foreign keys reference existing tables
- [ ] Unique constraints named descriptively
- [ ] No `description` column (use Universal Description Model)
- [ ] Monetary values use BIGINT cents, not DECIMAL
- [ ] Corresponding SwiftData model created or updated in `Packages/SharedModels/`
- [ ] System Architecture doc updated if this is a new table or structural change
