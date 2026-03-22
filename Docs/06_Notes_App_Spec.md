# Warm Productivity — Notes App Spec

**App #2 of 3 — Inherits shared infrastructure from App #1**

---

## Context Loading Guide

Load these documents and skills at the start of every Notes dev session:

| Load | Why |
|---|---|
| `CLAUDE.md` | Loaded automatically — hard rules, naming conventions, principles |
| `warm-productivity-system-architecture.md` | Full schema, sync model, cross-app data patterns |
| `warm-productivity-vision-and-philosophy.md` | Design philosophy, UX principles |
| `warm-productivity-cross-app-integration-map.md` | What this app reads/writes to shared tables, what's deferred |
| This document | Screens, flows, phases, edge cases |

Load the relevant skill for the current task type (see CLAUDE.md Skills table).

---

## App Overview

Notes is the simplest of the three apps and the connective tissue of the ecosystem. Every description written in the Expense Tracker or To-Do app is a note. Notes launches with content already in it — all the descriptions created as expense and task notes during App #1 automatically populate in the Inbox.

The core value proposition: a clean, distraction-free place to write, with markdown support and a timeline-first view. Everything connects back to where it came from.

---

## Build Phases

| Phase | Name | Scope |
|---|---|---|
| 1 | Core Notes | Create, edit (markdown), assign to notebook, hashtags, timeline view, pinning, search, delete |
| 2 | Export | Per-notebook export as consolidated `.md` file |

**Deferred to Step 12 (Cross-App UI):** Slash commands (`/expense`, `/todo`), Objects sidebar section, cross-app linked references UI.
**Deferred to Step 13 (AI Layer):** AI-powered natural language parsing (extract expenses and tasks from notes).

---

## Screens & Flows

### Authentication

Shared with the ecosystem. Same Sign in with Apple flow as the Expense Tracker. Returning users with a valid session land directly in the Notes app. See Expense Tracker App Spec for full auth screen details.

---

### Main Navigation

Notes uses a two-level navigation structure: a sidebar listing notebooks and sections, and a note list + editor that opens from each selection.

On iPhone: `NavigationSplitView` — sidebar collapses into a drawer accessed via the top-left menu button.
On iPad: `NavigationSplitView` — sidebar always visible alongside the note list and editor.

---

### Sidebar

The persistent navigation panel. Sections listed in order:

| Section | Type | Description |
|---|---|---|
| Inbox | Virtual view | Notes with `notebook_id = NULL`. Cannot be renamed or deleted. |
| Objects | Virtual view | **Objects** is a virtual sidebar section listing all cross-app entities (expenses and tasks) that were created from within this Notes app via slash commands. It queries `entity_links` where `link_context IN ('note_created_expense', 'note_created_task')`. Deferred to Step 12 — not visible in Phase 1. |
| *(user notebooks)* | Real notebooks | Listed by `sort_order`, each with its color indicator |

- Tapping any section → **Note List** for that section
- Long-press a notebook → rename or delete
- Deleting a notebook deletes all notes inside it (with confirmation warning)
- `+` button in sidebar → creates a new notebook (name + color)

---

### Note List

Displays all notes in the selected section (Inbox or a notebook). Sorted by `note_date` descending (newest first).

Layout:
- **Search bar** at the top — filters notes by title and content in real time
- **Pinned section** (notebooks only — not available in Inbox) — pinned notes appear above all others
- Notes listed as `DD/MM: TITLE` format using `note_date`
- Each row shows: date, title, and a one-line content preview
- **Swipe to delete** — triggers deletion warning (see Edge Cases)

---

### Note Editor

Opens when a note row is tapped. Full-screen editor.

Layout:
- **Title field** at the top — plain text. Supports `@NotebookName` for notebook assignment (parsed and stripped from display title on save)
- **Content area** — markdown editor. Renders markdown inline or supports a preview toggle.
- **Toolbar** (above keyboard):

| Button | Action |
|---|---|
| 📅 Date | Edit `note_date` — date picker |
| 📌 Pin | Toggle `is_pinned` (disabled in Inbox) |
| \# Hashtag | Hashtag multi-select |
| 👁 Visibility | Toggle `hidden_in_notes_app` |
| ··· More | Additional actions (move to notebook, delete) |

- All edits save automatically (`updated_at` updated on every keystroke debounce)
- Back arrow (top left) → Note List

---

### FAB — Quick Note Creation (present on all screens)

Tapping the FAB creates a new blank note and opens the Note Editor immediately.
- New note lands in Inbox (`notebook_id = NULL`) by default
- User assigns to a notebook via `@NotebookName` in the title field

---

## Standalone Features by Phase

### Phase 1 — Core Notes

- **Create note** — via FAB, opens editor immediately
- **Edit with markdown** — full markdown support in content area, saves automatically
- **Notebook assignment** — via `@NotebookName` in the title field, parsed on save
- **Hashtags** — multi-select via toolbar, `#name` convention
- **Timeline view** — notes listed as `DD/MM: TITLE` by `note_date` descending
- **Pinning** — available in notebooks only, pinned notes appear above others
- **Search** — filters by title and content in real time, available in all sections
- **Delete** — swipe to delete with contextual warning based on cross-app links
- **Inbox auto-population** — expense and task descriptions created in App #1 already present

### Phase 2 — Export
- Per-notebook export as a single consolidated `.md` file
- Notes within the notebook concatenated, separated by date headers

---

## Ecosystem Features

### What this app reads from shared tables

| Source | What is read |
|---|---|
| `note_entries` | All notes including those created via expense/task descriptions |
| `entity_links` | Link context to show which expense or task a note belongs to |

### What this app writes to shared tables

| Action | Shared table written |
|---|---|
| Any note created, edited, or deleted | `activity_log` |
| Any cross-app link created or soft-deleted | `entity_links` |

### What is explicitly deferred

| Feature | Deferred to |
|---|---|
| Slash commands (`/expense`, `/todo`) | Step 12 (Cross-App UI) |
| Objects sidebar section | Step 12 (Cross-App UI) |
| Cross-app linked references UI | Step 12 (Cross-App UI) |
| AI natural language parsing | Step 13 (AI Layer) |

---

## Data Model

See System Architecture — Notes Tables for the complete schema.

**Key behavioral notes:**
- **Inbox is a virtual view**, not a real notebook: `WHERE notebook_id IS NULL`
- Three date fields on every note: `note_date` (user-facing, modifiable), `created_at` (immutable system timestamp), `updated_at` (updated on every edit, drives sync)

---

## Edge Cases & Constraints

**Deletion warnings**
Notes can be linked to expenses or tasks. Deletion behaviour varies by context:

| Action | entity_link | note_entries | Expense sees note? | Notes sees note? |
|---|---|---|---|---|
| Delete in Notes only | Kept | `hidden_in_notes_app = true` | Yes | No |
| Delete in Expense/To-Do only | Soft-deleted | Untouched | No | Yes |
| Delete everywhere (either app) | Soft-deleted | `deleted_at` set | No | No |
| Delete source expense/task | Soft-deleted | `deleted_at` set | No | No |

"Delete everywhere" requires a user confirmation warning. Deleting a source item (expense or task) uses a standard deletion warning.

**Notebook deletion**
Deletes all notes inside (`WHERE notebook_id = deleted_notebook_id`). Requires confirmation warning since it cascades to content.

**Pinning in Inbox**
Not available. `is_pinned` cannot be `true` when `notebook_id IS NULL`.

**Notebook assignment via title**
The `@NotebookName` syntax is parsed only from the title field. The `@` prefix is stripped from the display title on save. If the notebook referenced by `@NotebookName` does not exist, it is **automatically created** with that name and assigned to the current user. The new notebook uses the default color. No confirmation prompt. This mirrors the auto-create behaviour for categories and hashtags across the other apps.

**Auto-create:** If the notebook name typed after `@` does not match any existing notebook, a new notebook is created automatically with that name, using the default color. No confirmation prompt — creation is immediate and can be undone by assigning the note to a different notebook.

**Edge cases:**
- If the title contains two or more `@` tokens (e.g., `Meeting @Work @Important`), only the first `@` token is treated as a notebook assignment. Any subsequent `@` tokens are left in the title as literal text.
- If the title consists only of an `@NotebookName` token with no other text, the note title becomes 'UNTITLED' and the note is assigned to that notebook.

**Soft deletes everywhere**
No hard deletes. Deleting a note sets `deleted_at`. Junction rows in `note_entry_hashtags` are soft-deleted. Tombstones propagate to other devices via delta sync.

**Offline behaviour**
All writes succeed locally and immediately. Sync resolves in the background. The user is never blocked by a network condition.
