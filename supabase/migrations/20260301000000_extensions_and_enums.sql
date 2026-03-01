-- Migration: Extensions and Enum Types
-- Enables required PostgreSQL extensions and creates all enum types
-- before any tables reference them.

-- ============================================================
-- Extensions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- ============================================================
-- Enum Types (16 total)
-- ============================================================

-- Expense Tracker enums
CREATE TYPE expense_category_type AS ENUM ('income', 'expense');
CREATE TYPE reconciliation_status AS ENUM ('draft', 'completed');
CREATE TYPE transaction_source_type AS ENUM ('inbox', 'ledger');

-- Cross-app enums
CREATE TYPE entity_source_type AS ENUM ('expense_inbox', 'expense_ledger', 'task', 'note');
CREATE TYPE entity_link_context AS ENUM ('expense_note', 'task_note', 'task_expense', 'note_created_expense', 'note_created_task');
CREATE TYPE action_type AS ENUM ('created', 'deleted', 'completed', 'modified');

-- Subscription enums
CREATE TYPE plan_tier AS ENUM ('free', 'pro');
CREATE TYPE subscription_status AS ENUM ('trialing', 'active', 'grace_period', 'billing_retry', 'expired', 'cancelled', 'revoked');
CREATE TYPE subscription_environment AS ENUM ('sandbox', 'production');

-- Recurrence enums (shared by Expense Tracker and To-Do)
CREATE TYPE recurrence_pattern AS ENUM ('daily', 'weekly', 'specific_days', 'monthly', 'yearly');
CREATE TYPE recurrence_anchor AS ENUM ('fixed', 'after_completion');

-- To-Do enums
CREATE TYPE subtask_mode AS ENUM ('independent', 'gated');
CREATE TYPE streak_frequency AS ENUM ('daily', 'weekly', 'monthly');
CREATE TYPE streak_goal_type AS ENUM ('achieve_all', 'reach_amount');
CREATE TYPE streak_recording_method AS ENUM ('auto', 'manual', 'complete_all');
CREATE TYPE todo_member_role AS ENUM ('owner', 'member');
