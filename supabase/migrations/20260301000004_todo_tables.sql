-- Migration: To-Do Tables + Cross-FK Additions
-- All To-Do app tables, plus ALTER TABLEs to add cross-app foreign keys
-- that couldn't be created earlier due to table ordering.
-- Tables: todo_categories, todo_tasks, todo_recurrence_rules,
--         todo_hashtags, todo_task_hashtags, todo_category_members,
--         streak_completions

-- ============================================================
-- todo_categories
-- ============================================================

CREATE TABLE IF NOT EXISTS todo_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  color      TEXT NOT NULL DEFAULT '#3b82f6',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version    INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ,
  synced_at  TIMESTAMPTZ,

  CONSTRAINT uq_todo_categories_user_name
    UNIQUE (user_id, name)
);

-- ============================================================
-- todo_tasks
-- Note: linked_inbox_id column created as nullable UUID without FK initially.
-- The FK to expense_transaction_inbox is added via ALTER TABLE below.
-- ============================================================

CREATE TABLE IF NOT EXISTS todo_tasks (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title                   TEXT NOT NULL DEFAULT 'UNTITLED',
  due_date                TIMESTAMPTZ,
  priority                INTEGER NOT NULL DEFAULT 0,
  is_completed            BOOLEAN NOT NULL DEFAULT false,
  completed_at            TIMESTAMPTZ,
  is_recurring            BOOLEAN NOT NULL DEFAULT false,
  parent_task_id          UUID REFERENCES todo_tasks(id) ON DELETE CASCADE,
  subtask_mode            subtask_mode,
  category_id             UUID REFERENCES todo_categories(id) ON DELETE RESTRICT,
  created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_to             UUID REFERENCES users(id) ON DELETE SET NULL,
  sort_order              INTEGER NOT NULL DEFAULT 0,
  has_financial_data      BOOLEAN NOT NULL DEFAULT false,
  linked_inbox_id         UUID,
  streak_frequency        streak_frequency,
  streak_goal_type        streak_goal_type,
  streak_goal_value       INTEGER,
  streak_recording_method streak_recording_method,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  version                 INTEGER NOT NULL DEFAULT 1,
  deleted_at              TIMESTAMPTZ,
  synced_at               TIMESTAMPTZ
);

-- ============================================================
-- todo_recurrence_rules
-- ============================================================

CREATE TABLE IF NOT EXISTS todo_recurrence_rules (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id        UUID NOT NULL REFERENCES todo_tasks(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pattern        recurrence_pattern NOT NULL,
  interval       INTEGER NOT NULL DEFAULT 1,
  days_of_week   INTEGER[],
  day_of_month   INTEGER,
  week_of_month  INTEGER,
  anchor         recurrence_anchor NOT NULL DEFAULT 'fixed',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  version        INTEGER NOT NULL DEFAULT 1,
  deleted_at     TIMESTAMPTZ,
  synced_at      TIMESTAMPTZ
);

-- ============================================================
-- todo_hashtags
-- ============================================================

CREATE TABLE IF NOT EXISTS todo_hashtags (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version    INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ,
  synced_at  TIMESTAMPTZ,

  CONSTRAINT uq_todo_hashtags_user_name
    UNIQUE (user_id, name)
);

-- ============================================================
-- todo_task_hashtags
-- ============================================================

CREATE TABLE IF NOT EXISTS todo_task_hashtags (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id    UUID NOT NULL REFERENCES todo_tasks(id) ON DELETE CASCADE,
  hashtag_id UUID NOT NULL REFERENCES todo_hashtags(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version    INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ,
  synced_at  TIMESTAMPTZ,

  CONSTRAINT uq_todo_task_hashtags_task_hashtag
    UNIQUE (task_id, hashtag_id)
);

-- ============================================================
-- todo_category_members
-- Phase 6 (Collaboration). Created now as part of full schema.
-- ============================================================

CREATE TABLE IF NOT EXISTS todo_category_members (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES todo_categories(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invited_by  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role        todo_member_role NOT NULL DEFAULT 'member',
  joined_at   TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  version     INTEGER NOT NULL DEFAULT 1,
  deleted_at  TIMESTAMPTZ,
  synced_at   TIMESTAMPTZ,

  CONSTRAINT uq_todo_category_members_category_user
    UNIQUE (category_id, user_id)
);

-- ============================================================
-- streak_completions
-- ============================================================

CREATE TABLE IF NOT EXISTS streak_completions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id    UUID NOT NULL REFERENCES todo_tasks(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date       DATE NOT NULL,
  value      INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version    INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ,
  synced_at  TIMESTAMPTZ,

  CONSTRAINT uq_streak_completions_task_date
    UNIQUE (task_id, date)
);

-- ============================================================
-- Cross-FK additions
-- Now that both expense_transaction_inbox and todo_tasks exist,
-- add the bidirectional foreign keys.
-- ============================================================

-- expense_transaction_inbox.linked_task_id → todo_tasks(id)
-- ON DELETE SET NULL: deleting a task nullifies the reference rather than blocking the delete.
ALTER TABLE expense_transaction_inbox
  ADD CONSTRAINT fk_expense_inbox_linked_task
  FOREIGN KEY (linked_task_id) REFERENCES todo_tasks(id) ON DELETE SET NULL;

-- todo_tasks.linked_inbox_id → expense_transaction_inbox(id)
-- ON DELETE SET NULL: deleting an inbox item nullifies the reference rather than blocking the delete.
ALTER TABLE todo_tasks
  ADD CONSTRAINT fk_todo_tasks_linked_inbox
  FOREIGN KEY (linked_inbox_id) REFERENCES expense_transaction_inbox(id) ON DELETE SET NULL;
