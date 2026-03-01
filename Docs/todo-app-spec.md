# Warm Productivity — To-Do App Spec

**App #3 of 3 — Inherits shared infrastructure from Apps #1 and #2**

---

## Context Loading Guide

Load these documents and skills at the start of every To-Do dev session:

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

The To-Do app manages tasks, tracks streaks, and lets completions trigger real financial actions. Inspired by Todoist and TickTick. It is built third because it is the most complex standalone app, and because Phase 3 of the To-Do app (Recurring Tasks) reuses the recurrence engine built during Phase 5 of the Expense Tracker.

**Core value proposition:** A focused task manager where completing a task can mean more than checking a box — it can start a streak, update a counter, or generate an expense.

---

## Build Phases

| Phase | Name | Scope |
|---|---|---|
| 1 | Core Tasks | Create, edit, set due date and priority, categories, hashtags, complete, delete |
| 2 | Subtasks | One level of nesting, independent and gated completion modes |
| 3 | Recurring Tasks | Recurrence rules, schedule anchoring — reuses recurrence engine from Expense Tracker Phase 5 |
| 4 | Streaks | Streak tracking, goal types, recording methods, auto-unachieve |
| 5 | Expense Connection (data layer) | Edge Function built immediately. `has_financial_data`, `linked_inbox_id`, financial fields read-only in Task Detail Modal. Full UI deferred to Step 12. |
| 6 | Collaboration | Shared categories (Todoist-style), members, ownership, access control |
| 7 | Export | CSV export of all tasks or filtered by category |

**Deferred to Step 12 (Cross-App UI):** Expense Planning view in To-Do, expense connection full UI (financial fields on tasks, linked inbox display), cross-app linked references UI.
**Deferred to Step 13 (AI Layer):** AI-powered task creation from voice or natural language.

---

## Screens & Flows

### Authentication

Shared with the ecosystem. Same Sign in with Apple flow as the Expense Tracker. Returning users with a valid session land directly in the To-Do app. See Expense Tracker App Spec for full auth screen details.

---

### Main Navigation

Bottom tab bar with 4 tabs inspired by Todoist: **Inbox · Today · Upcoming · Browse**

**Tab routing rules:**

| Tab | Query | Notes |
|---|---|---|
| Inbox | `category_id IS NULL AND is_completed = false` | Tasks with no category. Default destination for all new tasks unless a category is specified. |
| Today | `due_date::date <= CURRENT_DATE AND is_completed = false AND due_date IS NOT NULL` | Due today + all overdue. Overdue tasks shown in a separate "Overdue" section at the top of the list, then today's tasks below. |
| Upcoming | `due_date::date != CURRENT_DATE AND due_date IS NOT NULL AND is_completed = false` | Future tasks + overdue tasks. Overdue shown in an "Overdue" section at top; future tasks grouped by date below. |
| Browse | All incomplete tasks, organized by category / hashtag / priority / streaks | Filter hub. No date filter. |

**Key behaviours (modelled after Todoist):**
- Overdue tasks appear in BOTH Today and Upcoming — they're surfaced everywhere so they can't be missed.
- Tasks with no due date appear only in Inbox (if no category) or Browse (if they have a category). They never appear in Today or Upcoming.
- Completed tasks are hidden from all four tabs. A "Completed" section or separate view may be added in a future phase.
- Subtasks follow their parent — if a parent task is in Today, its subtasks appear nested under it regardless of their own due date.

---

### Inbox Tab

All tasks without a due date, plus any tasks that don't fit the other views. The unscheduled backlog. Query: `category_id IS NULL AND is_completed = false`.

Layout:
- Task list, sorted by `sort_order` (manual ordering)
- Each row: completion checkbox, title, priority indicator, category, hashtag indicator
- **Swipe to complete** — marks task done (`is_completed = true`, `completed_at` set)
- **Swipe to delete** — soft deletes the record

---

### Today Tab

Tasks due today plus overdue tasks. Query: `due_date::date <= CURRENT_DATE AND is_completed = false AND due_date IS NOT NULL`.

Layout:
- **Overdue section** (collapsable, shows count) — tasks with `due_date` before today that are not completed
- **Today section** — tasks with `due_date` = today
- Each row: same as Inbox
- Swipe to complete / swipe to delete

---

### Upcoming Tab

Tasks with future due dates, grouped by date. Query: `due_date::date != CURRENT_DATE AND due_date IS NOT NULL AND is_completed = false`.

Layout:
- Tasks grouped by `due_date`, ordered chronologically
- Each group header shows the date (e.g., "Tomorrow · Thu 27 Feb", "Fri 28 Feb")
- Each row: same as Inbox
- Swipe to complete / swipe to delete

---

### Browse Tab

Navigation hub for filtering tasks by category, hashtag, or priority. Modelled after the Todoist Browse/Explore screen. Shows all incomplete tasks, organized by category / hashtag / priority / streaks with no date filter.

Sections (each collapsable):

| Section | Shows | Tapping an item |
|---|---|---|
| Categories | All categories with task count | Filtered Task List (by category) |
| Hashtags | All hashtags with task count | Filtered Task List (by hashtag) |
| Priority | High / Medium / Low / None | Filtered Task List (by priority) |
| Streaks | All streak-enabled tasks (Phase 4) | Streak Detail |

- Back arrow → Browse Tab

---

### Filtered Task List

Same layout as Inbox, filtered by the selected criterion (category, hashtag, or priority). Back arrow → Browse Tab.

---

### Task Detail Modal

Half-screen modal. Opens when any task row is tapped. Used for both viewing and editing.

**Phase 1 fields displayed:**
- Title (editable)
- Due date (editable — date picker, or type Today / Tomorrow / Yesterday)
- Priority (editable — selector: None / Low / Medium / High)
- Category (editable — picker)
- Hashtags (editable — multi-select)
- Description / Note (editable — links to `note_entries` via Universal Description Model)
- Subtasks (Phase 2) — listed below description
- Recurrence (Phase 3) — pattern selector
- Streak settings (Phase 4) — frequency, goal type, recording method

**Financial fields (Phase 5+):** The `has_financial_data` flag, `linked_inbox_id`, and any expense-related read-only fields are not visible in Phase 1. The Task Detail Modal in Phase 1 shows only: title, due date, priority, category, hashtags, description, subtasks (Phase 2+), recurrence (Phase 3+), streaks (Phase 4+). Financial data appears in Phase 5.

All edits save immediately.

---

### FAB — Quick Task Creation (present on every screen)

Expands from bottom, same pattern as Expense Tracker. Panel layout:
1. **Title input** — supports inline command syntax (parsed on save)
2. **Description field** — note input (writes to `note_entries` via Universal Description Model)
3. **Toolbar** — individual field buttons:

| Button | Action |
|---|---|
| 📅 Date | Date picker. Also accepts: `Today`, `Tomorrow`, `Yesterday` typed inline |
| 🚩 Priority | Priority selector (None / Low / Medium / High) |
| @ Category | Category picker |
| \# Hashtag | Hashtag multi-select |
| ··· More | Recurrence, streak settings (later phases) |

**Quick-add command syntax:**

`[title] [@category] [#hashtag] [!priority] [date]`

| Token | Meaning | Example |
|---|---|---|
| Plain text | Task title | `Buy groceries` |
| `@Name` | Category | `@Personal`, `@Work` |
| `#name` | Hashtag | `#errands`, `#urgent` |
| `!level` | Priority | `!low`, `!medium`, `!high` |
| `Today` / `Tomorrow` / `Yesterday` | Date shortcuts | `Tomorrow` |

**Examples:**
- `Buy groceries @Personal #errands Tomorrow` → task with category, hashtag, and due date set
- `Call dentist @Health !high Today` → task with category, priority, and due today
- `Read chapter 3` → title only, no metadata parsed — all other fields empty

Unrecognised tokens are ignored. Partial input creates the task with whatever fields were successfully parsed. The raw input is not stored — parsed fields are written directly to their respective columns.

---

## Standalone Features by Phase

### Phase 1 — Core Tasks

- **Create task** — via FAB
- **Edit task** — via Task Detail Modal
- **Due date** — date picker or typed shortcut (Today / Tomorrow / Yesterday)
- **Priority** — four levels: None (0), Low (1), Medium (2), High (3)
- **Categories** — flat list, user-managed, color
- **Hashtags** — flat list, user-managed, sort order
- **Complete task** — swipe to complete or tap checkbox. Sets `is_completed = true` and `completed_at`
- **Delete task** — swipe to delete (soft delete, tombstone)
- **Descriptions** — write to `note_entries` via Universal Description Model

### Phase 2 — Subtasks

- One level of nesting only (subtasks cannot have children)
- Two completion modes on parent: **Independent** (parent completable anytime) or **Gated** (all subtasks must be done first)
- Subtasks listed in Task Detail Modal, add via `+` in that section

**Subtask completion state machine:**

**Independent mode** (`subtask_mode = 'independent'`):
- Parent task can be completed at any time regardless of subtask state.
- Completing the parent does not affect subtasks — each subtask keeps its own completion state.
- Un-completing the parent does not un-complete subtasks.

**Gated mode** (`subtask_mode = 'gated'`):
- The complete action on the parent is **disabled** until all subtasks are completed. The parent row shows a progress indicator instead of a completion checkbox: e.g., "2/4" or a partial fill circle.
- Completing the final subtask automatically enables (but does not trigger) the parent completion — the user still taps to complete the parent.
- **Un-completing a subtask** when the parent is already completed: the parent automatically reverts to incomplete. The subtask un-completes and the parent un-completes in the same operation.
- **Un-completing a parent** in gated mode: the parent reverts to incomplete. Subtasks keep their current completion state — they are not un-completed.

**Both modes:**
- Deleting a parent task deletes all its subtasks (cascading soft-delete: `deleted_at` set on all subtasks).
- Subtasks cannot be independently moved to a different parent — they must be detached first (set `parent_task_id = NULL`) and then re-attached.
- Maximum one level of nesting — subtasks cannot have their own subtasks.

### Phase 3 — Recurring Tasks

- Recurrence patterns: daily, weekly, specific days of week, monthly, yearly, custom
- Schedule anchoring: anchor to original schedule or from last completion (`next_from`)
- Reuses the recurrence engine built during Expense Tracker Phase 5
- Recurring tasks show next occurrence date, not a list of future instances

**Recurrence Picker UI**

Accessible from the Task Detail Modal (Phase 3+) via a "Recurrence" row. Opens a bottom sheet with:

1. **Pattern selector:** None · Daily · Weekly · Monthly · Yearly
2. **Sub-options per pattern:**
   - *Daily:* "Every [N] days" — interval picker (default: 1)
   - *Weekly:* "Every [N] weeks on [day toggles]" — interval picker + Mon/Tue/Wed/Thu/Fri/Sat/Sun toggle buttons
   - *Monthly:* Two options — "By date: [1–28]" (e.g., every 15th) or "By position: [1st/2nd/3rd/4th/Last] [weekday]" (e.g., every 2nd Tuesday)
   - *Yearly:* "Every [N] years" — uses the task's due date month and day
3. **Anchor toggle:** "Fixed schedule" (calendar-locked — rent on the 1st is always the 1st even if paid late) vs. "After completion" (floating — next due N days/weeks after you complete it)
4. **Human-readable preview:** Live text below the picker showing the plain-English summary. Examples: "Every Monday and Wednesday", "Every 15th of the month", "3 days after completion"

Maps directly to `todo_recurrence_rules` columns: `pattern`, `interval`, `days_of_week`, `day_of_month`, `week_of_month`, `anchor`.

### Phase 4 — Streaks

- Any task can optionally enable streak tracking (`streak_frequency` set)
- **Streak frequency:** daily, weekly, monthly
- **Goal types:** `achieve_all` (binary — did it or didn't) or `reach_amount` (hit a numeric target)
- **Recording methods:** `auto` (each tap increments by 1), `manual` (user enters a number), `complete_all` (one tap marks entire goal done)
- Streak count = consecutive periods where goal was met
- Auto-unachieve: Edge Function resets streak at period end if goal was not met
- Mid-streak configuration changes not allowed — user must reset streak first
- **Streaks section** in Browse tab — filtered view of tasks where `streak_frequency IS NOT NULL`
- **Streak Detail screen** — current streak count, today's progress, goal status, completion history

### Phase 5 — Expense Connection (data layer only)

**Data layer is built immediately. Full UI is deferred to Step 12 (Cross-App UI).**

- Tasks can carry financial data (`has_financial_data = true`)
- Financial fields stored in a linked `expense_transaction_inbox` record (not on the task itself)
- On first completion: Edge Function creates inbox record, links to task via `linked_task_id` / `linked_inbox_id`
- On subsequent completions (inbox fully filled): Edge Function creates ledger record directly. Task's `due_date` advances per recurrence rule.
- Streak, recurrence, and financial data are orthogonal — all can be active on the same task simultaneously
- Financial fields visible in Task Detail Modal (read-only — full editing and Expense Planning view live in Expense Tracker, wired in Step 12)

### Phase 6 — Collaboration

Collaboration works at the **category level**, modelled on Todoist's shared projects. A user shares a category with one or more other Warm Productivity users. All members of a shared category can:
- View all tasks in the category
- Create new tasks in the category
- Edit, complete, and delete tasks in the category
- See who created or last modified each task

**Ownership and access control:**
- The category owner (creator) controls the member list
- Members can leave; only the owner can remove members or delete the shared category
- If the owner deletes a shared category, it is deleted for all members

**Schema additions for Phase 6:**
- `category_members` table: `id`, `category_id`, `user_id`, `role` (owner/member), `invited_by`, `joined_at`, `created_at`, `updated_at`, `version`, `deleted_at`
- `todo_tasks.created_by` column: user_id of who created the task (already available from auth context)
- `todo_tasks.assigned_to` column: optional user_id, allows assigning responsibility for a specific task to one member

Shared categories are visually distinguished in the Browse tab with a people icon. Notifications for new tasks, completions, and comments are deferred to a future phase.

### Phase 7 — Export

Export all tasks as a flat CSV file. Columns: title, status (pending/completed), due_date, completed_at, priority, category, hashtags, notes, recurring (yes/no), created_at. Export is triggered from Settings. Users can choose to export all tasks or filter by category.

---

## Ecosystem Features

### What this app writes to shared tables

| Action | Shared table written |
|---|---|
| User adds a description to any task | `note_entries` (via Universal Description Model) + `entity_links` |
| Any task created, edited, or deleted | `activity_log` |
| Any cross-app link created or soft-deleted | `entity_links` |
| Task with financial data completed | Triggers Edge Function → `expense_transaction_inbox` or `expense_transactions` |

### What is explicitly deferred

| Feature | Deferred to |
|---|---|
| Expense Planning view in To-Do | Step 12 (Cross-App UI) |
| Cross-app linked references UI | Step 12 (Cross-App UI) |
| Voice and natural language task entry | Step 13 (AI Layer) |

---

## Data Model

**Local storage:** All data is persisted locally using SwiftData. The three apps share a single SwiftData store via an iOS App Group, meaning a task created in To-Do is instantly accessible in Notes and Expense Tracker without a network round-trip.

See System Architecture — To-Do Tables for the complete schema.

**Key behavioral notes:**
- Every task belongs to zero or one category, zero or more hashtags
- Descriptions live in `note_entries`, never as a column on the task (Universal Description Model)
- Subtasks: one level only, `parent_task_id` on child tasks
- Recurring tasks: one `todo_recurrence_rules` row per task
- Streak completions: one row per task per day, UNIQUE constraint on (task_id, date)

---

## Edge Cases & Constraints

**Task completion and streaks**
Completing a streak task records a `streak_completions` entry for today. Multiple completions on the same day UPDATE the existing row (increment value for `auto`, replace for `manual`/`complete_all`). They do not insert new rows — enforced by the UNIQUE constraint on (task_id, date).

**Mid-streak configuration changes**
Not allowed. `streak_frequency`, `streak_goal_type`, `streak_goal_value`, and `streak_recording_method` are locked while a streak is active. UI disables these fields. User must explicitly reset the streak first, which resets the streak count but preserves the completions history.

**Recurring task completion**
Completing a recurring task sets `is_completed = true` on the current instance and advances `due_date` to the next occurrence per the recurrence rule. The task is never "done" in the traditional sense — it resets.

**Task → Expense first completion**
When a task with `has_financial_data = true` is completed for the first time, an inbox record is created. Because amount, bank account, and category are missing, it goes to the Expense Tracker inbox (not ledger) with `linked_task_id` set. It appears in Expense Planning, not the standard Inbox. The user fills in financial fields from the Expense Tracker.

**Task → Expense subsequent completions**
Once the linked inbox record has all financial fields filled, subsequent completions generate ledger entries directly with no user intervention.

**Soft deletes everywhere**
No hard deletes on any mutable table. Deleting a task sets `deleted_at`. Junction rows in `todo_task_hashtags` are soft-deleted. Tombstones propagate via delta sync.

**Offline behaviour**
All writes succeed locally and immediately. Sync resolves in the background. The user is never blocked by a network condition.

**Subtask constraints**
One level of nesting only. A subtask (`parent_task_id IS NOT NULL`) cannot itself have subtasks. Gated mode (`subtask_mode = 'gated'`) prevents parent completion until all subtasks are `is_completed = true`.
