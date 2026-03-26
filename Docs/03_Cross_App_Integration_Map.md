# Warm Productivity — Cross-App Integration Map

**Version 1.0 — February 2026**

## What Is This Document?

This is the practical reference for every touchpoint between apps. The Architecture doc explains *how* the system works (schema, sync engine, patterns). This document answers: "I'm building app X — what exactly do I need to hook into?"

Organized by relationship, not by concept. Find the app pair you're working on, and you'll see every data flow, event, and UI surface that connects them.

## Integration Tier Reference

This document covers two integration tiers (see CLAUDE.md § Terminology for definitions):

**[Data Layer]** — Tables, columns, entity_links writes, and sync behaviour that are wired up during each app's standalone build phases. The schema exists from day one; apps write to shared tables as part of their standalone functionality.
**[Cross-App UI]** — UI surfaces, slash commands, linked reference panels, and interactive cross-app flows. None of these exist until Step 12 of the Development Roadmap.

## Shared Ecosystem Layer

These are the foundations that all three apps touch. Any app built in the ecosystem must integrate with all of these.

### Authentication (Shared Keychain)

All three apps share a single auth session via the iOS Keychain in a shared App Group. Signing into one app signs you into all three. Signing out of one signs you out of all three.

**What every app must do:**

- Read the auth token from the shared Keychain group on launch
- If no token exists, show the Sign in with Apple flow
- On successful sign-in, store the token in the shared Keychain group
- On sign-out, clear the shared Keychain token
- Include the auth token in all Supabase requests

### Entity Links (Cross-App Glue)

> **Canonical schema definition:** System Architecture § Entity Links Table. This section covers practical integration behavior.

**[Data Layer]** The `entity_links` table is the single mechanism for all cross-app relationships. Every app reads from and writes to this table.

**[Data Layer]** What every app must do:

- When creating a cross-app relationship (e.g., linking a note to an expense), create an `entity_link` row
- When displaying an item, query `entity_links` for any linked items to show references (e.g., "Linked to expense: Lunch at Noma")
- When deleting an item, check `entity_links` and present the appropriate deletion options ("remove from here" vs. "delete everywhere")
- When an item is deleted everywhere, soft-delete all `entity_links` rows referencing it (set `deleted_at`)

**[Data Layer]** Link contexts currently defined:

| link_context | source_type | target_type | Created by |
|---|---|---|---|
| `expense_note` | `expense_inbox` or `expense_ledger` | `note` | Expense Tracker (when user adds description to any expense type) |
| `task_note` | `task` | `note` | To-Do (when user adds description) |
| `task_expense` | `task` | `expense_inbox` or `expense_ledger` | To-Do (when task with financial data is completed). Initially targets inbox on first completion; updated to target ledger when the inbox record is promoted. |
| `note_created_expense` | `note` | `expense_inbox` or `expense_ledger` | Notes (via `/expense` slash command) |
| `note_created_task` | `note` | `task` | Notes (via `/todo` slash command) |

### Universal Description Model

**[Data Layer]** All three apps follow the same pattern: there is no `description` column on any entity. When a user adds a description to an expense or task, a `note_entry` is created and linked via `entity_links`.

**What every app must do:**

- Show a "description" input in the UI for any entity that supports it
- When the user types a description, create a `note_entry` (title = entity's title, content = the description text) and an `entity_link`
- Set `hidden_in_notes_app` on the new note based on the user's `linked_notes_visible_in_notes_app` setting in `user_settings`
- When displaying an entity, check for a linked note to show the description
- When editing the description, edit the linked `note_entry` directly
- Provide a per-note toggle so the user can override visibility (force-show a hidden note in Notes app, or force-hide a visible one)
- Respect the deletion matrix: "remove description" can either hide the note from Notes app (`hidden_in_notes_app = true`) or unlink it, depending on context

### Activity Logging

**[Data Layer]** Every app writes to the `activity_log` table when the user creates, deletes, completes, or modifies an entity.

**[Data Layer]** What every app must do:

- On entity create: write an activity_log entry with `action_type = 'created'`
- On entity delete: write an entry with `action_type = 'deleted'`
- On entity modify: write an entry with `action_type = 'modified'`
- On task complete (To-Do only): write an entry with `action_type = 'completed'`
- Include a human-readable `summary_text` (e.g., "Created expense: Lunch at Noma")

Each app has its own activity view, filtered by `entity_type`. The activity data lives in the shared `activity_log` table.

### User Settings

All three apps read from the shared `user_settings` table, but each app cares about different settings.

**Expense Tracker reads:**

- `main_currency` — the user's reporting currency. All transactions display their `amount_home_cents` converted to this currency. When changed, triggers recalculation of `exchange_rate` and `amount_home_cents` on all transactions (regular expenses use reference table rates; cross-currency transfers use implied rates when main_currency matches one leg). Original `amount_cents` in the account's currency is always immutable.
- `transaction_sort_preference` — controls transaction list sort order. Values: 'date' (transaction date) or 'created_at' (creation date). Default: 'date'.
- `budget_enabled` — when true, all expense categories must have a budget in `expense_budgets`. New categories require a budget immediately. @Debt categories default to 0 budget.
- `linked_notes_visible_in_notes_app` — default visibility for description notes created via the Universal Description Model. Never retroactive — only affects new notes. Per-note override always available.
- `theme` — light/dark/system appearance

**Notes reads:**

- `theme` — light/dark/system appearance

**To-Do reads:**

- `start_of_week` — for "This Week" and "Upcoming" smart filters and any week-based grouping
- `linked_notes_visible_in_notes_app` — default visibility for description notes created via the Universal Description Model. Never retroactive — only affects new notes. Per-note override always available.
- `theme` — light/dark/system appearance

**Shared by all three (the `user_settings` table itself is shared, but each app reads only the fields it needs):**

- `theme` — light/dark/system appearance

The table is extensible — new per-app preferences can be added as columns without affecting other apps.

### Unified Organizational Model

All three apps share the same two-layer organizational structure:

**Categories** — flat (no hierarchy), one per entity, structured, colored, sortable. Every category is directly assignable to entities — there are no parent/child categories, no groupings, no depth levels. Categories are the primary buckets where totals always add up cleanly. Each app has its own category tables (`expense_categories`, `todo_categories`, `note_notebooks`). An expense category "Food" and a to-do category "Food" are separate entities. Cross-app category linking is a potential future feature.

**Hashtags** — multiple per entity, freeform, lightweight. Hashtags provide cross-cutting context (e.g., #Vacation, #Dog, #TaxDeductible) without breaking the category structure. Each app has its own hashtag tables (`expense_hashtags` + `expense_transaction_hashtags`, `todo_hashtags` + `todo_task_hashtags`, `note_hashtags` + `note_entry_hashtags`). All three apps follow the same two-layer model: one category/notebook per entity for clean totals, multiple hashtags per entity for cross-cutting context.

**People & Transfers (Expense Tracker only)** — People are bank accounts with `is_person = true`. The `/` syntax creates a paired transaction on any target account — person or real. Shared expense: `-60 Lunch @Food $Chase /Eliana +30` creates two linked transactions (-60 on Chase @Food, +30 on Eliana @Debt). Inter-account transfer: `-60 Exchange $Chase /Chase_Credit +60` uses the same mechanism (-60 on Chase @Other, +60 on Chase_Credit @Other). There is no separate `expense_people` table. Full symbol convention: `@` for categories/notebooks, `#` for hashtags, `$` for primary bank account, `/` for paired transaction target (Expense Tracker) and slash commands (Notes), `+`/`-` for amount sign prefixes.

**Cross-user sharing** — When a person account has `linked_user_id` (linked to a real Warm Productivity user via invitation), paired transactions on that account create a `transaction_shares` row. The linked user sees the transaction sign-flipped in their app. One transaction, two readers, no duplication. Each user has their own category and notes. A two-party confirmation flow locks amount, title, currency, and date once both parties agree. Any edit resets the other party's confirmation. All receiver edits go through a database function that enforces the locking logic. Person accounts without `linked_user_id` work in single-user mode with no `transaction_shares` row.

**Presentation model:** In breakdown views (e.g., monthly expense table by category), transactions within a category are grouped by their exact hashtag combination so rows don't overlap and numbers sum to the category total. This grouping is purely a UI concern — the database stores individual hashtag links via junction tables, not combinations. Filtering by a single hashtag (e.g., "show all #Vacation expenses") pulls every transaction with that hashtag regardless of other hashtags attached.

**What every app must do:**

- Provide a flat category system with: user-owned categories, display color, sort_order, soft deletes. No hierarchy.
- Provide a hashtag system with: user-owned hashtags, many-to-many junction table, soft deletes. All three apps have hashtags.
- Hashtags apply to all records in the app (for expenses, both inbox and ledger items; for notes, all notes including Inbox notes)

The user learns one mental model — flat categories as buckets for clean totals, hashtags as cross-cutting context filters — and it works the same way everywhere.

### Cross-App Editing Scope

When one app displays or interacts with another app's data, it can edit a **scoped set of relevant fields** inline. For the full editing experience, the user opens the source app. This keeps each app focused on its domain while enabling meaningful cross-app interaction.

**Expense fields editable from other apps:** amount, currency, title, category.

**To-Do fields editable from other apps:** title, due date, completed status, category.

**Notes fields editable from other apps:** content (the description text — single field only).

**How this applies to each interaction:**

| From App | Editing In | Editable Fields | For Full Edit |
|---|---|---|---|
| Notes | Expenses (slash commands) | Amount (with sign), title, date, category, bank account. All mandatory fields — goes directly to ledger if date is today/past. | Open Expense Tracker (for exchange rate, people splits, description) |
| Notes | To-Dos (slash commands) | Title, due date, completed (checkbox), category, hashtag | Open To-Do (for priority, recurrence, streaks) |
| Expense Tracker | Notes (descriptions) | Content only | Open Notes |
| To-Do | Notes (descriptions) | Content only | Open Notes |
| To-Do | Expenses (financial data on task) | Amount, currency, category (read from linked inbox record). Title is independent — task title and expense title are separate fields. | Open Expense Tracker |
| Expense Tracker | To-Dos (linked tasks from Expense Planning) | Title, due date, recurrence pattern (via linked task) | Open To-Do (for non-financial task fields like priority) |
| Expense Tracker | Expense Planning records (inbox with `linked_task_id`) | Full expense data: title, amount, currency, bank account, category, exchange rate, description | N/A (Expense Tracker owns the inbox table) |

**[Data Layer — schema and data model only; feature UI ships in Expense Tracker Build Phase 5]** The Expense Planning section in the Expense Tracker is a **filtered view of the inbox table** — it shows all `expense_transaction_inbox` records that have a `linked_task_id`, sorted by the linked task's `due_date`. Both recurring and one-off planned expenses live here. There is no separate creation form in the Planning section — planned expenses are created via the FAB by setting a future date (see Future-date routing below). From this view, the user can:

- **View** all upcoming planned expenses sorted by the linked task's due date
- **Edit** inbox templates directly. Changes to financial fields apply to all future generated expenses.
- **Register/confirm** a planned expense when it happens, which completes the linked task, triggering the inbox → ledger promotion flow. The expense registers to the ledger with the **completion date** (not the task's due date).

**Overdue section:** A subset of Expense Planning where the linked task's `due_date` is today or past and the task is not completed. The user can complete them or reschedule (update the task's due date).

The linked tasks also appear in the To-Do app as normal tasks, where the user sees the restricted cross-app expense fields (title, amount, currency, category — read from the linked inbox record) plus normal to-do fields (due date, recurrence, completed status). Completing the task from the To-Do app triggers the same expense generation flow.

**Future-date routing** *(data model described here; feature UI ships in Expense Tracker Build Phase 5, after Expense Planning is built)***:** When a user adds an expense with a future date (any date after today) via the FAB, the system creates an `expense_transaction_inbox` record (`date = null`) and a linked `todo_task` with the future date as `due_date` (plus a `todo_recurrence_rule` if the user sets a recurrence pattern). The expense appears in Expense Planning. When the user adds an expense with today's date or a past date, a normal expense is created directly (inbox or ledger depending on field completeness).

**One occurrence at a time:** For recurring planned expenses, the inbox template is persistent and the linked task shows the next due date. When registered, a ledger entry is generated with the completion date and the linked task's `due_date` advances to the next occurrence. Schedule anchoring is configurable per recurrence rule (anchor to original schedule or from last completion). One-off planned expenses are consumed (deleted) on registration. This keeps the list clean — one row per recurring expense, plus any one-off planned expenses.

## App Pair: Expense Tracker ↔ Notes

### Data That Flows Between Them

| Direction | What | How |
|---|---|---|
| Expense → Notes | Expense description | When user adds description to an expense, a `note_entry` is created and linked via `entity_links` (context: `expense_note`) |
| Notes → Expense | New expense via slash command | `/expense` command in note content creates an `expense_transaction_inbox` or `expense_transactions` record and links via `entity_links` (context: `note_created_expense`) |

### Events That Trigger Cross-App Actions

**User adds description to an expense (Expense Tracker):**

1. Expense Tracker creates a `note_entry` (title = expense title, content = description text)
2. Expense Tracker creates an `entity_link` (source: expense, target: note, context: `expense_note`)
3. The note appears in the Notes app Inbox (or in a notebook if `@NotebookName` is in the title)
4. If `hidden_in_notes_app` is set, the note is accessible via the expense but hidden from Notes app views

**User edits a description (either app):**

1. Both apps read/write the same `note_entry` record
2. Edits from either app update the same row — no duplication
3. Sync engine handles multi-device conflict resolution via version-based last-write-wins

**[Cross-App UI — Step 12]** Slash commands — simplified registration flow (Step 12)

When a user types `/expense` or `/todo` in a Note, a **bottom sheet** slides up with a simplified creation form. No inline preview card is embedded in the note body — the note text remains clean.

**`/expense` bottom sheet fields:** title, amount, currency, category. All other expense fields (account, exchange rate, date, hashtags) default or are filled in Expense Tracker.

**`/todo` bottom sheet fields:** title, due date, priority, category. All other task fields are filled in To-Do.

On submit: the entity (expense inbox record or todo task) is created. An `entity_link` is written connecting the note to the new entity (`link_context = 'note_created_expense'` or `'note_created_task'`). The note body is unchanged — no inline card or embedded preview. The created entity appears in the **Objects tab** in the Notes sidebar, where all entities spawned from notes are visible.

On cancel: nothing is created. The typed `/expense` or `/todo` text remains as plain text.

### UI Surfaces That Reference the Other App

**In Expense Tracker:**

- Description field on expense detail view → reads/writes from linked `note_entry`
- "Linked note" indicator → shows when an expense has a linked note, tappable to open in Notes app

**In Notes:**

- **[Cross-App UI — Step 12]** Linked references section in note detail → shows "Linked to expense: Lunch at Noma" when a note is connected to an expense
- **[Cross-App UI — Step 12]** `/expense` slash command rendering → static display of linked expense within note content (after user confirms the inline preview card)
- **[Cross-App UI — Step 12]** Objects sidebar section → **Objects defined:** The Objects section is a virtual sidebar view in the Notes app listing all cross-app entities (expenses, tasks) created from within Notes via slash commands. Populated by querying `entity_links` where `link_context IN ('note_created_expense', 'note_created_task')`. Shows entity type, title, key info, and source note. Clicking opens details in the third panel.
- **[Cross-App UI — Step 12]** Inbox → auto-generated expense notes appear here until assigned to a notebook

### Deletion Behavior

| Action | What happens |
|---|---|
| Delete expense (source that originated the note) | `entity_link` gets `deleted_at` set. `note_entry` gets `deleted_at` set (note deleted everywhere). Standard deletion warning — no extra warning needed since deleting an item obviously deletes its description. |
| Delete note in Notes app only | `entity_link` is kept. `note_entry` gets `hidden_in_notes_app = true`. Expense still sees the note as its description. |
| Delete note everywhere (from Notes) | `entity_link` gets `deleted_at` set. `note_entry` gets `deleted_at` set. Expense loses its description. User sees a confirmation warning. |

## App Pair: To-Do ↔ Notes

### Data That Flows Between Them

| Direction | What | How |
|---|---|---|
| To-Do → Notes | Task description | When user adds description to a task, a `note_entry` is created and linked via `entity_links` (context: `task_note`) |
| Notes → To-Do | New task via slash command | `/todo` command in note content creates a `todo_tasks` record and links via `entity_links` (context: `note_created_task`) |
| Notes ↔ To-Do | Completion state sync | Checking a `/todo` checkbox in a note syncs to `todo_tasks.is_completed`, and vice versa |

### Events That Trigger Cross-App Actions

**User adds description to a task (To-Do):**

1. To-Do creates a `note_entry` (title = task title, content = description text)
2. To-Do creates an `entity_link` (source: task, target: note, context: `task_note`)
3. The note appears in the Notes app Inbox
4. Same edit/sync behavior as expense descriptions


**[Cross-App UI — Step 12]** User checks the checkbox in a note (Notes):

1. Notes app finds the `entity_link` for this checkbox
2. Updates the linked `todo_tasks` record: `is_completed = true`, `completed_at = now()`
3. If the task has `has_financial_data = true`, this triggers the Task → Expense flow (see Expense ↔ To-Do section)
4. The task shows as completed in the To-Do app

**[Cross-App UI — Step 12]** User completes a task in To-Do app:

1. To-Do sets `is_completed = true`, `completed_at = now()`
2. Sync engine propagates the change
3. Any note containing a `/todo` checkbox linked to this task updates to checked state: `- [x] Buy groceries`

### UI Surfaces That Reference the Other App

**In To-Do:**

- Description field on task detail view → reads/writes from linked `note_entry`
- "Linked note" indicator → shows when a task has a linked note

**In Notes:**

- **[Cross-App UI — Step 12]** Linked references section → shows "Linked to task: Buy groceries" when a note is connected to a task
- **[Cross-App UI — Step 12]** `/todo` slash command rendering → interactive checkbox with bidirectional sync (after user confirms the inline preview card)
- **[Cross-App UI — Step 12]** Objects sidebar section → same section as above, also shows to-dos created from slash commands
- **[Cross-App UI — Step 12]** Inbox → auto-generated task notes appear here

### Deletion Behavior

Same matrix as Expense ↔ Notes, replacing "expense" with "task":

| Action | What happens |
|---|---|
| Delete task (source that originated the note) | `entity_link` gets `deleted_at` set. `note_entry` gets `deleted_at` set (note deleted everywhere). Standard deletion warning — no extra warning needed since deleting an item obviously deletes its description. |
| Delete note in Notes only | `hidden_in_notes_app = true`. Task still sees description. |
| Delete note everywhere | `entity_link` gets `deleted_at` set. `note_entry` gets `deleted_at` set. Task loses description. Warning shown. |

**Special case — deleting a note that contains `/todo` checkboxes:** The linked `todo_tasks` records survive. They lose their note reference but continue to exist independently in the To-Do app. The `entity_link` rows get `deleted_at` set.

## App Pair: Expense Tracker ↔ To-Do

### Data That Flows Between Them

| Direction | What | How |
|---|---|---|
| To-Do → Expense | Expense generated on task completion | When a task with `has_financial_data = true` is completed: if a linked inbox record exists with all financial fields filled, it generates a ledger entry from the inbox template data (with completion date); if not, it creates an inbox entry with the task's title. |
| Expense → To-Do | Planned expense creation | The Expense Tracker's "Expense Planning" section creates `expense_transaction_inbox` records (financial data, `date = null`) and linked `todo_tasks` with `due_date` (for scheduling/recurrence). Also triggered automatically when the user adds an expense with a future date. |

This is a bidirectional relationship. Task completions generate expenses (To-Do → Expense). The Expense Tracker creates planned expenses in its own inbox table and linked tasks in the To-Do domain for scheduling — this is the one exception to the general rule that apps don't write to each other's domain tables.

### Events That Trigger Cross-App Actions

**[Data Layer]** User completes a task with financial data — first time (no linked inbox record):

1. To-Do marks the task complete: `is_completed = true`, `completed_at = now()`
2. An Edge Function fires, checks `has_financial_data = true`, checks for a linked inbox record via `linked_inbox_id` — none found
3. Creates an `expense_transaction_inbox` record with the task's title and `date = null`. Since it has a `linked_task_id`, it appears in Expense Planning (not the Inbox view). Sets `linked_task_id` on the inbox record and `linked_inbox_id` on the task.
4. Creates an `entity_link` (source: task, target: expense_inbox, context: `task_expense`)
5. The expense appears in the Expense Tracker's Expense Planning section. The user fills in remaining financial fields (amount, bank account, category). If the task is recurring, the inbox record is marked `is_recurring = true` and becomes the persistent template.
6. Activity log records the task completion and expense creation.

**[Data Layer]** User completes a recurring task — subsequent times (linked inbox record exists with all financial fields filled):

1. To-Do marks the task complete, recurrence engine generates next occurrence
2. Edge Function fires, checks `has_financial_data = true`, finds linked inbox record via `linked_inbox_id` with all financial fields filled
3. Creates an `expense_transactions` record directly in the ledger using financial fields from the inbox template, with `date` set to the **task completion date** (current date — not the task's due date)
4. Creates an `entity_link` (source: task, target: expense_ledger, context: `task_expense`)
5. Advances the linked task's `due_date` to the next occurrence per the recurrence rule and schedule anchoring setting (anchor to original schedule or from last completion)
6. The expense appears in the Expense Tracker ledger immediately — no user intervention needed

**Editing individual vs. future occurrences:**

- Editing a specific month's generated expense does NOT affect the inbox template. One-off changes stay isolated.
- Editing the inbox template is done from the Expense Planning section in the Expense Tracker. All future completions use the updated values.

**Descriptions:** The inbox template can have its own linked note (description) via the Universal Description Model. Each generated ledger expense is a fresh entity and does NOT inherit the template's description. Per-occurrence descriptions are added manually if needed.

**User uncompletes a task that generated an expense (To-Do):**

The generated expense is NOT automatically deleted. Once an expense exists, it's a real financial record. The user must delete it manually from the Expense Tracker if they want to remove it. The `entity_link` remains, showing the relationship.

### UI Surfaces That Reference the Other App

**In To-Do:**

- Financial fields on task detail → only visible when `has_financial_data = true`. Shows the restricted cross-app expense fields: amount, currency, category (read from the linked inbox record via `linked_inbox_id`). The task has its own independent title — editing the task title does NOT change the expense title, and vice versa. Full expense management (expense title, bank account, exchange rate, description) lives in the linked inbox record, accessible from the Expense Planning section.
- Simple indicator: "Generates expense on completion"
- "Generated expense" indicator on completed tasks → shows the linked expense after completion, tappable to open in Expense Tracker

**In Expense Tracker:**

- "Expense Planning" section → filtered view of `expense_transaction_inbox` where `linked_task_id IS NOT NULL`, sorted by linked task's `due_date`. Includes both recurring templates (persistent, `date = null`) and one-off planned expenses. Shows full expense data plus linked task's due date. The user manages inbox templates here — editing updates the record directly. Allows **registering/confirming** planned expenses when they happen (which completes the linked task, promoting to ledger with the completion date). No creation form in this section — planned expenses are created via the FAB by setting a future date.
- "Overdue" section → subset of Expense Planning where linked task's `due_date` is today or past and task not completed. Shows planned expenses whose due date has passed without confirmation.
- "Generated from task" indicator on individual expenses → shows when an expense was created by a task completion, tappable to open in To-Do
- Each generated expense is otherwise a normal ledger entry — fully editable, deletable, reconcilable

### Deletion Behavior

| Action | What happens |
|---|---|
| Delete task in To-Do | `entity_link` gets `deleted_at` set. Previously generated expenses survive as standalone ledger entries — never deleted. For recurring expenses, the inbox template loses automation and moves to Inbox view. |
| Delete single recurring expense in Expense Tracker | User prompted: **"Delete this expense only"** — soft-deletes the single ledger entry, recurring template and linked task remain active. **"Delete all future occurrences"** — soft-deletes the inbox template and linked task, stops future generation. Previously generated ledger entries are never affected. |
| Delete one-off expense in Expense Tracker | `entity_link` gets `deleted_at` set. Task survives in To-Do (still marked complete, financial data intact). |
| Delete either everywhere | The deleted item gets `deleted_at` set. `entity_link` gets `deleted_at` set. The other item survives independently. |

## Integration Matrix — Quick Reference

Every cross-app event in one table. Scan this when you need to know what fires when.

| Trigger | Source App | Creates In | Edge Function? | entity_link context |
|---|---|---|---|---|
| User adds description to expense | Expense Tracker | note_entries | No | `expense_note` |
| User adds description to task | To-Do | note_entries | No | `task_note` |
| User types `/expense` in note | Notes | expense_transaction_inbox or expense_transactions (goes directly to ledger if all fields present and date is today/past) | Yes (slash command processing) | `note_created_expense` |
| User types `/todo` in note | Notes | todo_tasks | Yes (slash command processing) | `note_created_task` |
| User checks `/todo` checkbox in note | Notes | Updates todo_tasks | No (direct sync) | Uses existing `note_created_task` link |
| User completes task in To-Do | To-Do | Updates checkbox in note_entries | No (direct sync) | Uses existing `note_created_task` link |
| User completes task with financial data (first time, no linked inbox record) | To-Do | expense_transaction_inbox (with `linked_task_id`, `date = null`) | Yes (expense from task completion) | `task_expense` |
| User completes recurring task (linked inbox template exists with financial fields filled) | To-Do | expense_transactions (direct to ledger from inbox template, with completion date) | Yes (task completion promotion) | `task_expense` |
| User adds expense with future date via FAB (recurring or one-off) | Expense Tracker | expense_transaction_inbox (`date = null`) + linked todo_task with future `due_date` (+ todo_recurrence_rules if recurring) | Yes (planned expense creation) | N/A (entity_link created on task completion) |
| User registers/confirms planned expense in Expense Tracker | Expense Tracker | Completes linked todo_task → promotes inbox → ledger (with completion date) | Yes (task completion promotion) | `task_expense` (created at this point) |
| User deletes item ("remove from here") | Any | Sets deleted_at on entity_link only | No | N/A |
| User deletes item ("delete everywhere") | Any | Sets deleted_at on item and all entity_links | No | N/A |
| User deletes source item (expense/task that originated a note) | Any | Sets deleted_at on source item, linked note, and all entity_links | No | N/A |

## Future Integration Hooks

These are integration points that don't exist yet but are already accounted for in the architecture. Build them into the data layer now so they're ready when needed.

### Already Built Into the Schema

- **`entity_links` supports arbitrary entity types.** The `source_type` and `target_type` enums can be extended to include new apps (e.g., 'calendar_event', 'journal_entry') without schema changes to the entity_links table itself.
- **`activity_log` supports arbitrary entity types.** The `entity_type` field is plain text, not an enum. Any new app can log to it immediately.
- **`user_settings` is extensible.** New columns can be added for new app preferences without affecting existing apps.

### Future Cross-App Features (Not Yet Designed)

- **Cross-app category linking:** An expense category "Food" and a to-do category "Food" are currently independent. A future feature could link them, enabling cross-app filtering ("show me everything related to Food").
- **Category-by-hashtag views:** Viewing expenses within a category filtered by hashtag (e.g., all "Food" expenses tagged `#trip-to-paris`). Same pattern for to-dos. The flat category + hashtag model already supports this — it's a query concern, not a schema concern. The hashtag combination presentation grouping (where rows within a category are grouped by exact hashtag set) is the primary way users drill into category data.
- **Cross-app activity view:** Each app already has its own activity view filtered by entity_type. Future: a unified activity view combining all apps' entries in chronological order.
- **Unified search:** Search across all three apps from any app. Low priority — users typically search within a single app.
- **Shared timeline:** A chronological view combining expenses, tasks, and notes. Would read from all three apps' tables plus entity_links.
- **AI natural language parsing:** Write a note in plain language, have the system extract structured data (expenses, tasks, dates, amounts) and create them. Extends the slash command concept with intelligence.

### What a New App Must Hook Into

If a fourth app is added to the ecosystem (e.g., Calendar, Journal, Reading List):

1. **Entity Links** — add new `source_type`/`target_type` values and `link_context` values for its cross-app relationships
2. **Universal Description Model** — if the new app's entities support descriptions, follow the same pattern (create note_entries, link via entity_links)
3. **Activity Logging** — write to `activity_log` with the new entity_type
4. **Auth** — read from shared Keychain, use the same Supabase auth token
5. **User Settings** — read shared settings, add app-specific settings as new columns
6. **Slash Commands** — optionally add a new `/command` in the Notes app for creating entities in the new app
7. **Repository Pattern** — create app-specific repositories following the same contract (read local, write local, sync background)

No changes to existing apps are required. The new app plugs into the shared layer and existing apps discover linked items through `entity_links` queries.

---

*This document should be updated as new cross-app features are designed or new apps are added to the ecosystem.*
