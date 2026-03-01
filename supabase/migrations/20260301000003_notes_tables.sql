-- Migration: Notes Tables
-- All Notes app tables.
-- Tables: note_notebooks, note_entries, note_hashtags, note_entry_hashtags

-- ============================================================
-- note_notebooks
-- Created before note_entries since entries FK to notebooks.
-- ============================================================

CREATE TABLE IF NOT EXISTS note_notebooks (
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

  CONSTRAINT uq_note_notebooks_user_name
    UNIQUE (user_id, name)
);

-- ============================================================
-- note_entries
-- ON DELETE CASCADE on notebook_id: architecture doc states
-- "Deleting a notebook deletes all notes in it."
-- ============================================================

CREATE TABLE IF NOT EXISTS note_entries (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title                TEXT NOT NULL DEFAULT 'UNTITLED',
  content              TEXT,
  notebook_id          UUID REFERENCES note_notebooks(id) ON DELETE CASCADE,
  is_pinned            BOOLEAN NOT NULL DEFAULT false,
  note_date            TIMESTAMPTZ NOT NULL DEFAULT now(),
  hidden_in_notes_app  BOOLEAN NOT NULL DEFAULT false,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  version              INTEGER NOT NULL DEFAULT 1,
  deleted_at           TIMESTAMPTZ,
  synced_at            TIMESTAMPTZ,

  -- Pinning is only valid when a note belongs to a notebook.
  -- Inbox notes (notebook_id = NULL) cannot be pinned.
  CONSTRAINT chk_note_pinned_requires_notebook
    CHECK (notebook_id IS NOT NULL OR is_pinned = false)
);

-- ============================================================
-- note_hashtags
-- ============================================================

CREATE TABLE IF NOT EXISTS note_hashtags (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version    INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ,
  synced_at  TIMESTAMPTZ,

  CONSTRAINT uq_note_hashtags_user_name
    UNIQUE (user_id, name)
);

-- ============================================================
-- note_entry_hashtags
-- ============================================================

CREATE TABLE IF NOT EXISTS note_entry_hashtags (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id    UUID NOT NULL REFERENCES note_entries(id) ON DELETE CASCADE,
  hashtag_id UUID NOT NULL REFERENCES note_hashtags(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version    INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ,
  synced_at  TIMESTAMPTZ,

  CONSTRAINT uq_note_entry_hashtags_note_hashtag
    UNIQUE (note_id, hashtag_id)
);
