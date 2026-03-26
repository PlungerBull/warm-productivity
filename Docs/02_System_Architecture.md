# Warm Productivity — System Architecture

**Version 1.0 — February 2026**

## What Is This Document?

This is the structural blueprint for the Warm Productivity ecosystem. It defines how the system is built, how the three apps relate to each other, and the technical decisions behind those choices. A developer (or AI) should be able to read this and understand how to add a new app without breaking anything.

For the *why* behind these decisions, see the Vision & Philosophy document. This document covers the *how*.

## High-Level System Overview

Warm Productivity is three native iOS apps — Expense Tracker, Notes, and To-Do — that share a common data layer and cloud backend.

```
┌─────────────────────────────────────────────────────┐
│                   iOS Device                         │
│                                                      │
│  ┌──────────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │   Expense     │ │  Notes   │ │     To-Do        │ │
│  │   Tracker     │ │   App    │ │      App         │ │
│  └──────┬───────┘ └────┬─────┘ └────────┬─────────┘ │
│         │              │                │            │
│  ┌──────┴──────────────┴────────────────┴─────────┐ │
│  │           Shared Swift Packages                 │ │
│  │  (Data Models, Sync Engine, UI Components,      │ │
│  │   Supabase Client, Auth)                        │ │
│  └──────────────────┬─────────────────────────────┘ │
│                     │                                │
│  ┌──────────────────┴─────────────────────────────┐ │
│  │     SwiftData (Local SQLite via App Group)      │ │
│  └──────────────────┬─────────────────────────────┘ │
│                     │                                │
└─────────────────────┼───────────────────────────────┘
                      │ Sync Engine
                      ▼
┌─────────────────────────────────────────────────────┐
│                   Supabase                           │
│                                                      │
│  ┌──────────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │  PostgreSQL   │ │ Storage  │ │   Edge Functions  │ │
│  │  (all tables) │ │ (photos) │ │ (complex writes,  │ │
│  │              │ │          │ │  exchange rates)   │ │
│  └──────────────┘ └──────────┘ └──────────────────┘ │
│  ┌──────────────┐ ┌──────────────────────────────┐  │
│  │     Auth      │ │      Real-time Subscriptions │  │
│  │ (Sign in w/   │ │      (websockets)            │  │
│  │  Apple)       │ │                              │  │
│  └──────────────┘ └──────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

**The core principle:** the UI never talks to Supabase directly. It always reads from and writes to the local SwiftData store. The sync engine is the only component that touches the network. This is what makes every app feel instant.

## Tech Stack

> **Canonical source for the tech stack table:** CLAUDE.md § Tech Stack. This section provides architectural rationale.

### Client

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Local Persistence:** SwiftData (Apple's modern persistence framework, built on Core Data/SQLite)
- **Local Data Sharing:** App Groups (all three apps share the same local SwiftData store for instant cross-app data access)
- **Target Platforms (in order):** iOS → macOS → Windows → Browser

### Backend

- **Platform:** Supabase (managed backend-as-a-service)
- **Database:** PostgreSQL (single project, single database, all tables together)
- **File Storage:** Supabase Storage (S3-backed, for receipt photos and attachments)
- **Auth:** Supabase Auth with Sign in with Apple
- **Server Logic:** Supabase Edge Functions (for complex writes and scheduled tasks)
- **Real-time:** Supabase Real-time subscriptions via websockets

### Why These Choices

**Native Swift over cross-platform:** the Vision demands Things 3 level of polish. Native delivers the best animations, gestures, and system integration (widgets, Shortcuts, notifications). The cost is separate codebases for Windows later, but iOS and macOS share Swift/SwiftUI.

**Supabase over custom backend:** provides PostgreSQL, auth, storage, real-time, and Edge Functions in one managed platform. No server maintenance. The free tier is generous for a personal project. Row Level Security means data isolation is enforced at the database level, not in application code.

**SwiftData over Core Data:** SwiftData is Apple's modern, Swift-native API. It's cleaner, less boilerplate, and works identically on iOS and macOS. Under the hood it's still SQLite, so when the Windows app is built, the same schema works via raw SQLite.

**App Groups over cloud-only sync:** three separate iOS apps need to see each other's data. Without App Groups, opening the Notes app after adding an expense note would require waiting for cloud sync. App Groups share the local SQLite store so cross-app data is available instantly.

## Monorepo Structure

All three apps and shared code live in a single repository.

```
warm-productivity/
├── Apps/
│   ├── ExpenseTracker/          # Expense Tracker iOS app
│   │   ├── ExpenseTracker.xcodeproj
│   │   ├── Sources/
│   │   └── Resources/
│   ├── Notes/                   # Notes iOS app
│   │   ├── Notes.xcodeproj
│   │   ├── Sources/
│   │   └── Resources/
│   └── ToDo/                    # To-Do iOS app
│       ├── ToDo.xcodeproj
│       ├── Sources/
│       └── Resources/
├── Packages/
│   ├── SharedModels/            # SwiftData entities, shared across all apps
│   ├── RecurrenceEngine/        # Shared recurrence logic: pattern evaluation, next-date calculation, schedule anchoring
│   ├── SyncEngine/              # Sync logic, conflict resolution, queue management
│   ├── SupabaseClient/          # Supabase SDK configuration, auth, API helpers
│   ├── SharedUI/                # Design system: colors, typography, spacing, shared components
│   └── SharedUtilities/         # Common helpers, extensions, formatters
├── Supabase/
│   ├── migrations/              # Numbered SQL migration files
│   ├── functions/               # Edge Functions (complex writes, exchange rates)
│   └── seed.sql                 # Initial data (default categories, onboarding content)
├── Docs/
│   ├── 01_Vision_and_Philosophy.md
│   ├── 02_System_Architecture.md    # This document
│   ├── 03_Cross_App_Integration_Map.md
│   ├── 04_Development_Roadmap.md
│   ├── 05_Expense_Tracker_App_Spec.md
│   ├── 06_Notes_App_Spec.md
│   ├── 07_Todo_App_Spec.md
│   └── 08_Changelog.md
├── Skills/                      # Claude skills for AI-assisted development
└── CLAUDE.md                    # Project-level AI instruction file
```

Each app imports the shared packages it needs. All three import SharedModels, SyncEngine, SupabaseClient, and SharedUI. App-specific code stays in its own directory.

## Database Design

### Single Database, Prefixed Table Names

One Supabase project, one PostgreSQL database. All tables live together. Table names are prefixed by app to indicate ownership, with shared tables having no prefix.

### Schema Conventions (applies to all tables)

- **Amounts in cents:** All monetary values are stored as `bigint` in cents (e.g., $30.50 = 3050). This avoids floating point issues with financial data.
- **Soft deletes:** All tables use `deleted_at` (nullable timestamp) instead of hard deletes. A NULL value means active; a timestamp means soft-deleted and when it was deleted.
- **Optimistic locking:** All mutable tables have a `version` (integer, default 1) column, incremented on every update. Prevents stale overwrites.
- **Sync fields:** All mutable tables include `synced_at` (timestamp). See Sync Engine section.
- **UUIDs everywhere:** All primary keys are UUIDs generated locally via `uuid_generate_v4()`.
- **Timestamps:** `created_at` and `updated_at` on every table, both `timestamp with time zone`, defaulting to `now()`.
- **Unified naming:** All entities use `title` (text, NOT NULL, default 'UNTITLED') as their display name. There is no `description` column anywhere — see Universal Description Model below.

**Exceptions to mutable table conventions:** The following tables are exempt from soft deletes, optimistic locking, and sync fields because they are not mutable user data:

- **`global_currencies`** — static lookup table. Rows are predefined (USD, PEN, etc.) and never edited or deleted by users. Uses `code` (text) as primary key instead of UUID for readability and foreign key convenience.
- **`exchange_rates`** — append-only reference table. One row per currency pair per day, never edited or soft-deleted. Has `created_at` and `updated_at` but no `version`, `deleted_at`, or sync fields.
- **`users`** — managed by Supabase Auth. Follows Supabase's own conventions, not the app's mutable table conventions.
- **`activity_log`** — append-only audit trail. Entries are never edited or deleted by users. No `version` or `deleted_at`.

### Universal Description Model

**There is no `description` column on any table in the ecosystem.** All extended text content lives in `note_entries`.

When a user adds a "description" to an expense or a to-do, the system:

1. Creates a `note_entry` — the note's `title` is always set to the source item's `title` (the expense title or the task title). The description text becomes the note's `content`. If the source item's title changes later, the linked note's title updates to match.
2. Creates an `entity_link` connecting the expense/todo to that note
3. The note is now visible in the Notes app (unless `hidden_in_notes_app` is set)

This means:

- **Expenses** have a `title` and their domain-specific fields (amount, date, account, etc.). No description column.
- **To-Dos** have a `title` and their domain-specific fields (due date, priority, category, etc.). No description column.
- **Notes** have `title` and `content`. The `content` field on `note_entries` IS the universal description for the entire ecosystem.

The UI in each app shows a description input field. But behind the scenes, typing in that field always creates or edits a linked `note_entry`. This is a UX concept, not a database column.

**Visibility in the Notes app:** When a linked note is created (from an expense or task description), the `hidden_in_notes_app` field is set based on the user's `linked_notes_visible_in_notes_app` setting in `user_settings`. If `true` (default), the note appears in the Notes app. If `false`, it's hidden from the Notes app but still accessible from the source expense/task. The user can override visibility on individual notes at any time — force-show a hidden note or force-hide a visible one. Changing the global setting is **never retroactive** — it only affects notes created after the change. Existing notes keep their current visibility.

**Why this matters:** `note_entries` is the single source of truth for all text content in the ecosystem. No data duplication, no sync conflicts between separate text fields, and every description is automatically searchable and browsable in the Notes app (unless the user opts out via the visibility setting).

### Shared Tables

```
users
  - id (UUID, primary key)
  - email (text)
  - display_name (text)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())

user_settings
  - user_id (UUID, primary key, foreign key → users)
  - theme (text, default 'system') — 'light', 'dark', or 'system'
  - start_of_week (integer, default 0) — 0=Sunday, 1=Monday, etc.
  - main_currency (text, default 'USD', foreign key → global_currencies.code)
  - transaction_sort_preference (text, default 'date') — how transactions are sorted in the Expense Tracker. Values: 'date' (transaction date), 'created_at' (creation date). To-Do task sorting preferences will be added later (e.g., priority, due date, alphabetical, project).
  - budget_enabled (boolean, NOT NULL, default false) — when true, all expense categories must have a budget in expense_budgets. New categories require a budget immediately. @Debt categories default to 0 budget.
  - linked_notes_visible_in_notes_app (boolean, NOT NULL, default true) — default visibility for notes created via Universal Description Model (expense/task descriptions). When false, new linked notes are hidden from the Notes app by default. Per-note override always available. Never retroactive — only affects notes created after the setting is changed.
  - sidebar_show_bank_accounts (boolean, NOT NULL, default true) — controls visibility of Bank Accounts section in Expense Tracker Transactions sidebar
  - sidebar_show_people (boolean, NOT NULL, default true) — controls visibility of People section in Expense Tracker Transactions sidebar
  - sidebar_show_categories (boolean, NOT NULL, default true) — controls visibility of Categories section in Expense Tracker Transactions sidebar
  - display_timezone (text, NOT NULL, default 'UTC') — IANA timezone string (e.g., 'America/Lima', 'America/New_York'). Defaults to UTC; set to device timezone on first launch. All "today" and date-boundary calculations use this timezone. Synced across devices.
  - todo_tab_show_inbox (boolean, NOT NULL, default true) — To-Do tab visibility: Inbox
  - todo_tab_show_today (boolean, NOT NULL, default true) — To-Do tab visibility: Today
  - todo_tab_show_upcoming (boolean, NOT NULL, default true) — To-Do tab visibility: Upcoming
  - todo_tab_show_browse (boolean, NOT NULL, default true) — To-Do tab visibility: Browse. Todoist-style: user can hide any tab they don't use. At least one tab must remain visible (enforced client-side).
  - expense_tab_show_budgeting (boolean, NOT NULL, default true) — Expense Tracker tab visibility: Budgeting (only meaningful once Phase 2 is installed)
  - expense_tab_show_reconciliations (boolean, NOT NULL, default true) — Expense Tracker tab visibility: Reconciliations (only meaningful once Phase 3 is installed)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())

**Timezone Architecture:**
All timestamps are stored as `timestamptz` in UTC — Postgres handles the conversion automatically. The `display_timezone` field in `user_settings` controls the user's local time context. All client-side "today" calculations, date boundary checks (for task due dates, overdue detection, streak period boundaries, and inbox promotion eligibility) convert UTC to the user's `display_timezone` before comparison. The scheduled Edge Function for streak auto-unachieve evaluates each user's period boundaries in their own `display_timezone`, not UTC. On first app launch, the app sets `display_timezone` to the device's current timezone string (via `TimeZone.current.identifier`).

global_currencies
  - code (text, primary key) — e.g., 'USD', 'EUR', 'PEN'
  - name (text, NOT NULL) — e.g., 'US Dollar'
  - symbol (text, NOT NULL) — e.g., '$'
  - flag (text, nullable) — emoji flag for display

exchange_rates  ← GLOBAL REFERENCE TABLE. No user_id. No RLS. No sync protocol. No version/deleted_at/synced_at. Populated exclusively by a scheduled Supabase Edge Function that fetches daily rates from an exchange rate API. All users read from this single shared table. Never written to by client apps.
  - id (UUID, primary key, default uuid_generate_v4())
  - base_currency (text, NOT NULL, foreign key → global_currencies.code) — always 'USD' (single-base approach: all rates expressed as 1 USD = X target_currency)
  - target_currency (text, NOT NULL, foreign key → global_currencies.code) — the non-USD currency (e.g., 'PEN', 'HKD')
  - rate (numeric, NOT NULL) — how many units of target_currency per 1 USD (e.g., 3.75 means 1 USD = 3.75 PEN)
  - rate_date (date, NOT NULL) — the date this rate applies to
  - fetched_at (timestamptz, default now()) — when this rate was recorded
  - created_at (timestamptz, default now())
  - UNIQUE constraint: (base_currency, target_currency, rate_date) — one rate per currency pair per day

entity_links
  - id (UUID, primary key)
  - source_type (enum: 'expense_inbox', 'expense_ledger', 'task', 'note')
  - source_id (UUID)
  - target_type (enum: 'expense_inbox', 'expense_ledger', 'task', 'note')
  - target_id (UUID)
  - link_context (enum: 'expense_note', 'task_note', 'task_expense', 'note_created_expense', 'note_created_task')
  - user_id (UUID, foreign key → users)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1) — required for delta sync detection
  - deleted_at (timestamptz, nullable) — soft delete, required for tombstone sync propagation to other devices
  - synced_at (timestamptz, nullable) — last confirmed server sync
```

### Expense Tracker Tables

**One currency per bank account.** Each bank account has exactly one currency. If a real-world card supports multiple currencies (e.g., a credit card with PEN and USD), the user creates separate accounts — one per currency. This keeps the model simple: no mixed-currency accounts, no per-transaction currency overrides within an account. The account's currency determines the currency of every transaction in it. The same rule applies to person virtual accounts (`is_person = true`) — if you share expenses with Eliana in both PEN and USD, she has two virtual accounts (one per currency), auto-created when she's first tagged on an expense in each currency.

```
expense_bank_accounts
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - name (text, NOT NULL)
  - currency_code (text, NOT NULL, default 'USD', foreign key → global_currencies.code) — one currency per account, immutable after creation
  - is_person (boolean, NOT NULL, default false) — true for virtual accounts representing people (debt tracking). Person accounts appear in the People section of the sidebar, not the regular accounts list.
  - linked_user_id (UUID, nullable, foreign key → users) — for future collaboration: links a person account to a real Warm Productivity user. When linked, shared expenses can push notifications/inbox entries to the other user's app. Only applicable when is_person = true.
  - color (text, NOT NULL, default '#3b82f6') — UI display color
  - is_visible (boolean, NOT NULL, default true) — hide without deleting
  - current_balance_cents (bigint, NOT NULL, default 0) — cached running balance. Updated client-side immediately when a transaction is written (offline-first: the local SwiftData write atomically updates both the transaction and the account balance). A PostgreSQL trigger on expense_transactions provides server-side recalculation as a correctness backstop — if a sync conflict produces drift, the trigger corrects it on the next server write. Never query this as a SUM() at read time; always read the cached value.
  - is_archived (boolean, NOT NULL, default false) — when true, the account is hidden from all transaction pickers and new-entry flows but preserved in full for historical records and reports. Cannot be deleted if it has any transactions.
  - sort_order (integer, NOT NULL, default 0) — controls display order in the Transactions tab sidebar. User-adjustable via drag-to-reorder in the Transactions tab.
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (user_id, name, currency_code)

expense_categories
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, foreign key → users)
  - name (text, NOT NULL)
  - category_type (enum expense_category_type: 'income', 'expense', NOT NULL, default 'expense') — determines which section the category appears in on the budget dashboard. System categories @Debt and @Other are 'expense'. User-created categories default to 'expense' and can be changed to 'income'.
  - color (text, NOT NULL) — UI display color
  - sort_order (integer, NOT NULL, default 0)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (user_id, name)

expense_transaction_inbox
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - title (text, NOT NULL, default 'UNTITLED') — display name of the expense
  - amount_cents (bigint, nullable)
  - date (timestamptz, nullable, default now())
  - account_id (UUID, nullable, foreign key → expense_bank_accounts)
  - category_id (UUID, nullable, foreign key → expense_categories)
  - exchange_rate (numeric, default 1.0) — converts from account currency to user's main_currency for display. Auto-filled from exchange_rates reference table, user-overridable. 1.0 when account currency = main_currency.
  - is_recurring (boolean, NOT NULL, default false) — true if this record serves as a persistent template for a recurring expense. Recurring templates have date = null permanently.
  - linked_task_id (UUID, nullable, foreign key → todo_tasks) — the linked task that drives recurrence scheduling (via todo_recurrence_rules) and completion-based promotion to ledger. Null for expenses created without a task.
  - source_text (text, nullable) — raw text from CSV import or quick capture
  - (description/notes live in note_entries, linked via entity_links — Universal Description Model)
  - receipt_photo_url (text, nullable)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields

expense_transactions
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - title (text, NOT NULL) — display name of the expense (required on ledger, no UNTITLED allowed)
  - amount_cents (bigint, NOT NULL)
  - amount_home_cents (bigint, nullable) — cached display value: amount_cents converted to user's main_currency via exchange_rate. Recalculated when main_currency changes. Not a source of truth — always derivable from amount_cents * exchange_rate.
  - date (timestamptz, NOT NULL, default now())
  - account_id (UUID, NOT NULL, foreign key → expense_bank_accounts)
  - category_id (UUID, NOT NULL, foreign key → expense_categories) — always required on ledger records. Person accounts use @Debt, inter-account transfers use @Other, all other expenses have a user-assigned category.
  - exchange_rate (numeric, NOT NULL, default 1.0) — converts from account currency to user's main_currency for display. Auto-filled from exchange_rates reference table, user-overridable (real-world rates vary by vendor). 1.0 when account currency = main_currency. See Exchange Rates section for recalculation rules on main_currency change.
  - transfer_id (UUID, nullable) — links two transactions as an account transfer
  - inbox_id (UUID, nullable, foreign key → expense_transaction_inbox) — lineage back to inbox origin
  - reconciliation_id (UUID, nullable, foreign key → expense_reconciliations)
  - cleared (boolean, NOT NULL, default false) — confirmed on bank statement, pre-reconciliation
  - source_text (text, nullable) — raw text from CSV import or quick capture
  - (description/notes live in note_entries, linked via entity_links — Universal Description Model)
  - receipt_photo_url (text, nullable)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields

expense_reconciliations
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - account_id (UUID, NOT NULL, foreign key → expense_bank_accounts)
  - name (text, NOT NULL)
  - date_start (timestamptz, nullable)
  - date_end (timestamptz, nullable)
  - status (enum reconciliation_status: 'draft', 'completed', default 'draft')
  - beginning_balance_cents (bigint, NOT NULL, default 0)
  - ending_balance_cents (bigint, NOT NULL, default 0)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields

expense_budgets
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - category_id (UUID, NOT NULL, foreign key → expense_categories) — one budget per category
  - amount_cents (bigint, NOT NULL) — monthly budget amount in the user's main_currency
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (user_id, category_id) — one budget per category per user

expense_hashtags
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - name (text, NOT NULL)
  - sort_order (integer, NOT NULL, default 0) — controls display order in the sidebar
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (user_id, name)

expense_transaction_hashtags
  - id (UUID, primary key, default uuid_generate_v4())
  - transaction_id (UUID, NOT NULL) — references expense_transactions OR expense_transaction_inbox
  - transaction_source (enum: 'inbox', 'ledger', NOT NULL) — which table the transaction lives in
  - hashtag_id (UUID, NOT NULL, foreign key → expense_hashtags)
  - user_id (UUID, NOT NULL, foreign key → users)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (transaction_id, hashtag_id)

```

**People are bank accounts.** There is no separate `expense_people` table. A person (Eliana, Carlos) is simply a bank account with `is_person = true`. Creating a person creates a bank account row. If you share expenses with Eliana in both PEN and USD, she has two rows in `expense_bank_accounts` — one per currency — auto-created when she's first tagged on an expense in a new currency. The People section in the sidebar queries `expense_bank_accounts WHERE is_person = true`, groups by name, and shows per-currency balances.

**The `/` syntax — unified paired transactions.** The `/` prefix in the Expense Tracker means "create a second transaction on this account." It works identically for people and real bank accounts. This unifies what were previously two separate concepts (people splits and inter-account transfers) into one mechanism.

**Category rules for paired transactions:**

| Scenario | Primary transaction (`$`) | Paired transaction (`/`) |
|---|---|---|
| Real account + Person | User's specified @Category | @Debt (automatic) |
| Real account + Real account | @Other (automatic, generic) | @Other (automatic, generic) |
| Person only (as `$`) | @Debt (automatic) | N/A (single transaction) |

**System category — @Debt:** Auto-created on first person account creation. Non-deletable, non-renamable. `category_type = 'expense'`. All transactions involving person accounts are categorized under @Debt (on the person's side). This keeps expense reports clean — the @Debt category total shows the user's net receivable/payable position across all people. Each person's individual balance is visible via their account's `current_balance_cents` (positive = they owe you, negative = you owe them).

**System category — @Other:** Auto-created on first inter-account transfer. Non-deletable, non-renamable. `category_type = 'expense'`. Used for transfers between two real bank accounts where no meaningful expense category applies.

**Examples:**

*Shared expense (you pay, someone owes you):*
`-60 Lunch @Food $Chase_USD /Eliana +30` → Two transactions:
1. -60 on Chase_USD, category @Food
2. +30 on Eliana (USD), category @Debt
Result: Your @Food shows -60, Eliana owes you 30. Your net spend is -30.

*Multiple people:*
`-90 Dinner @Food $BCP_PEN /Eliana +20 /Carlos +30` → Three transactions:
1. -90 on BCP_PEN, category @Food
2. +20 on Eliana (PEN), category @Debt
3. +30 on Carlos (PEN), category @Debt
No validation that shares sum to the expense total.

*Settlement (someone pays you back):*
`+30 Settlement @Food $Chase_USD /Eliana -30` → Two transactions:
1. +30 on Chase_USD, category @Food
2. -30 on Eliana (USD), category @Debt
Result: Eliana's balance goes to 0.

*Someone else pays for you (you owe them):*
`-30 Lunch @Food $Eliana` → One transaction:
1. -30 on Eliana's account, category @Food
Result: Eliana's balance goes to -30 (you owe her). Your @Food shows -30. Your real bank accounts are untouched.

*Inter-account transfer:*
`-60 Exchange $Chase_USD /Chase_Credit +60` → Two transactions:
1. -60 on Chase_USD, category @Other
2. +60 on Chase_Credit, category @Other
Same mechanism as people splits — just between two real accounts.

**People in the sidebar:** The sidebar shows a "People" section listing each person account with their running balance (from `current_balance_cents`). People with accounts in multiple currencies show each balance separately, grouped by name. Tapping a person shows all transactions on their account(s) — the full history of what they owe you and what you owe them.

**Reconciliation lives in its own tab, not the sidebar.** The Expense Tracker has a dedicated Reconciliations tab (added in Phase 3) for managing reconciliation batches — creating, viewing, completing, and un-reconciling. There is no Reconciliation section in the Transactions sidebar. Assigning transactions to a batch happens from the transaction list via a batch action in the transaction context menu. See the Expense Tracker App Spec for the full Reconciliations tab design.

**Reconciliation field-locking rules:** When a batch is completed, four fields lock on every transaction in the batch: `amount_cents`, `account_id`, `title`, `date`. All other fields (category, hashtags, description, exchange rate, receipt photo, cleared) remain editable regardless of reconciliation state. Un-reconciling the batch unlocks all four fields.

### Budget Tracking

Monthly per-category budgets for both income and expense categories. Budgets are a static template — set once, they repeat every month until manually edited or the feature is toggled off.

**Core rules:**

- **All-or-nothing:** When `budget_enabled` is true in `user_settings`, every expense category must have a corresponding `expense_budgets` row. Creating a new category while budgets are active requires setting a budget amount immediately.
- **@Debt defaults to 0:** When budgets are activated, @Debt categories auto-receive a budget of 0 (user can change). All other categories (including @Other) require the user to set an amount.
- **Monthly static template:** The `amount_cents` in `expense_budgets` is the same every month. No rollover, no surplus carry, no deficit carry. Each month is independent.
- **Set in main_currency:** Budget amounts are in the user's `main_currency`. Comparison is against `amount_home_cents` sums across all accounts for that category within the calendar month.
- **No total budget:** Only per-category budgets exist. The total is the derived sum of all category budgets.
- **Across all accounts:** Budget comparison sums transactions from all bank accounts, not per-account.

**"Spent" calculation:** No stored totals. The dashboard queries `expense_transactions` for each visible month: `SUM(amount_home_cents) WHERE category_id = X AND date within month`. Compared against the `expense_budgets.amount_cents` for that category.

**When main_currency changes:** Budget amounts stay as-is (they're already abstract targets). The "spent" side recalculates automatically because `amount_home_cents` on transactions is recalculated (see Exchange Rates section).

**Dashboard table — 3-month view:** Categories as rows, 3 months as columns — showing a rolling 3-month window with the current month as the rightmost column. Each cell shows: actual spend (sum of `amount_home_cents`) and budget amount. Categories are split into income and expense sections based on `category_type`. All amounts in `main_currency`. System categories @Debt and @Other (`category_type = 'expense'`) appear in the expense section. The user scrolls backward with [← →] arrows to see older months. Budget amounts in past month columns are read-only; the current month column supports inline editing.

### Cross-User Shared Expenses

When a person account has `linked_user_id` set (linked to a real Warm Productivity user via invitation), shared expenses become visible to both parties. The core principle: **one transaction, two readers, no duplication.**

```
transaction_shares
  - id (UUID, primary key, default uuid_generate_v4())
  - transaction_id (UUID, NOT NULL, foreign key → expense_transactions) — the paired transaction on the person account
  - user_id (UUID, NOT NULL, foreign key → users) — the receiver (the linked user)
  - category_id (UUID, nullable, foreign key → expense_categories) — receiver's own category for this transaction
  - originator_confirmed (boolean, NOT NULL, default false) — has the creator confirmed the final terms
  - receiver_confirmed (boolean, NOT NULL, default false) — has the receiver confirmed the final terms
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (transaction_id, user_id)
```

**How it works — end to end:**

1. You type: `-60 Lunch @Food $Chase /Eliana +30`
2. System creates Transaction A (`-60`, Chase, @Food, your `user_id`) — your spending record
3. System creates Transaction B (`+30`, Eliana account, @Debt, your `user_id`) — the debt record, linked by `transfer_id`
4. System detects Eliana's person account has `linked_user_id` → creates a `transaction_shares` row pointing to Transaction B with Eliana's UUID as `user_id`
5. Eliana opens her app → her query finds transactions where she has a `transaction_shares` row → she sees Transaction B **sign-flipped**: `-30 Lunch` (she owes you)
6. Eliana can set her own category via the `category_id` on her share row, and attach her own notes via `entity_links`
7. Both parties confirm via the confirmation flow (see below)

**Invitation flow:** Linking a person account to a real user requires an explicit invitation. The originator sends an invite from their person account; the receiver accepts. On acceptance, the system sets `linked_user_id` on the person account. The invitation mechanism (UI, notifications, invite codes) is defined in the app spec, not the architecture.

**Querying shared expenses (receiver's perspective):** The receiver's app runs a query that combines two result sets: (1) all transactions where `user_id = me` (their own expenses), and (2) all `expense_transactions` joined to `transaction_shares` where `transaction_shares.user_id = me` (expenses shared with them by others). For group 2, the app flips the sign at the display layer. One query, both sides covered.

**RLS for shared expenses:** The standard RLS policy (`user_id = auth.uid()`) covers the originator. An additional policy grants **read access** to transactions that have a `transaction_shares` row where `transaction_shares.user_id = auth.uid()`. The receiver does NOT have direct write access to `expense_transactions` — all edits go through a database function (see below).

**Independent per user (no locking needed):**

- **Category** — the originator's category lives on the transaction (`expense_transactions.category_id`). The receiver's category lives on their `transaction_shares` row (`transaction_shares.category_id`). Each person categorizes independently.
- **Description/notes** — each user creates their own `note_entry` linked to the transaction via `entity_links`. The Universal Description Model already supports this. No shared description field.

**Confirmation and field-locking flow:**

Both `originator_confirmed` and `receiver_confirmed` start as `false`. Either party can edit the shared transaction's lockable fields before both confirm. The flow:

1. Transaction is created: both confirmations = `false`
2. Either party reviews and optionally edits lockable fields
3. One party confirms (sets their flag to `true`)
4. **If the other party edits any lockable field, the first party's confirmation resets to `false`** — any edit invalidates the other's agreement
5. Both parties confirm → lockable fields become immutable

**Fields that lock once both confirm:**

- `amount_cents` — the core financial agreement
- `title` — the shared label for the expense
- Currency (derived from the account's `currency_code`) — ensures both parties agree on the same value
- `date` — when the expense happened

**Fields that never lock:**

- Category (independent per user)
- Description/notes (independent per user via `entity_links`)

**Edit gatekeeper — database function:** All receiver edits to shared transactions go through a Supabase database function (not direct table writes). This function enforces:

1. If both `originator_confirmed` and `receiver_confirmed` are `true` → reject edits to lockable fields
2. If only one is confirmed and the other party edits a lockable field → apply the edit and reset the confirmed party's flag to `false`
3. The receiver can always edit their own `transaction_shares` row (category, confirmation flag) via standard RLS

The originator's edits also go through this function when a `transaction_shares` row exists, ensuring the same locking and reset logic applies symmetrically.

**Person accounts without `linked_user_id`:** When `linked_user_id` is null (the person is not a Warm Productivity user), no `transaction_shares` row is created. The expense exists only in the originator's account. The system works identically to single-user mode — no confirmation flow, no shared visibility. This is the default for all person accounts until an invitation is accepted.

**Multi-person shared expenses:** When an expense is split across multiple people (e.g., `/Eliana +20 /Carlos +30`), each person account that has `linked_user_id` gets its own `transaction_shares` row. Each linked user sees only their portion. Confirmations are independent per share — confirming with Eliana doesn't affect Carlos's confirmation state.

**Symbol convention:** `@` for categories/notebooks, `#` for hashtags, `$` for primary bank account, `/` for paired transaction target (people or accounts in Expense Tracker) and slash commands (Notes), `+`/`-` for amount sign prefixes. Five symbols, consistent within each app's context. `/` means different things in different apps — in Notes it triggers slash commands (`/expense`, `/todo`), in the Expense Tracker it creates paired transactions (`/Eliana +20`, `/Chase_Credit +60`). No collision since paired transactions only happen in the Expense Tracker.

**Transaction lifecycle:** created (inbox or ledger) → promoted (inbox → ledger when conditions are met) → included (transaction is assigned to a reconciliation batch that is still draft — all fields remain editable) → reconciled (batch is completed — locks `amount_cents`, `account_id`, `title`, and `date`). A transaction can be created directly in the ledger if all mandatory fields are present and the date is today or past, skipping the inbox entirely. Transitions: normal → included (assign to draft batch via transaction menu batch action), included → normal (remove from batch), included → reconciled (batch completed), reconciled → included (un-reconcile batch from reconciliation section). Fields not locked by reconciliation (category, hashtags, description, exchange rate, receipt photo, cleared) remain editable in all states.

**Transfers and paired transactions:** When the `/` syntax is used, the system creates linked `expense_transactions` records sharing the same `transfer_id`. This applies to both inter-account transfers (`/Chase_Credit +60`) and people splits (`/Eliana +20`). The `transfer_id` column links the paired transactions. Category assignment follows the rules in the category table above. Multiple `/` targets on one expense each get their own paired transaction, all sharing the same `transfer_id` as the primary transaction.

**Inbox record visibility — derived from data, no flag needed:**
- **Inbox view** (no `linked_task_id`): Standalone records. Items with incomplete data need attention — the user fills in missing fields. When all mandatory fields (including date) are present and date is today or past, the item shows a "ready" indicator and a small Promote button. The user taps Promote to move the expense to the ledger. This lets users add optional fields (hashtags, description, receipt photo) before promoting.
- **Expense Planning section** (has `linked_task_id`): All task-linked inbox records. The due date for display and sorting comes from the linked task's `due_date`, not from the inbox record's `date` (which is null for recurring templates). Includes both recurring templates and one-off planned expenses.
- **Overdue section** (subset of Expense Planning where the linked task's `due_date` is today or past and the task is not completed): Planned expenses whose due date has passed without being confirmed. The user can complete them or reschedule.

**Inbox promotion — two paths:**

**Path 1: No linked task (standalone expense).** Promotion is user-initiated. When all mandatory fields are present (title, amount, bank account, category, date) AND the date is today or past, the inbox item shows a "ready" indicator and a small Promote button. Exchange rate auto-fills from the reference table and never blocks promotion. The user taps Promote to trigger the promotion. This lets users add optional fields (hashtags, description, receipt photo) before promoting. An Edge Function validates, inserts into `expense_transactions` (ledger), deletes the inbox record, and updates entity_links to point to the new ledger record. If any mandatory field is missing, the Promote button is hidden and the record stays in the Inbox view.

**Path 2: Linked task (planned expense).** Promotion happens ONLY when the linked task is completed — not automatically based on date. The Edge Function copies the inbox record's financial data (title, amount, bank account, category, exchange rate) into a new `expense_transactions` record. The `date` on the ledger entry is set to the **task completion date** (the current date at the moment of completion — not the task's due date). Any existing `entity_links` pointing to the inbox record are updated to point to the new ledger record (target_id and target_type change from inbox to ledger). For one-off planned expenses (`is_recurring = false`), the inbox record is consumed (deleted after ledger insertion). For recurring planned expenses (`is_recurring = true`), the inbox record persists as the template (date stays null), and the linked task's `due_date` advances to the next occurrence per the recurrence rule. Schedule anchoring is configurable per recurrence rule: "anchor to original schedule" (next occurrence follows the original pattern regardless of completion date) or "schedule from last completion" (next occurrence is calculated relative to the completion date).

**Mandatory fields for ledger (all must be present):**

- `title` — must have a real value (not 'UNTITLED')
- `amount_cents` — must be set
- `date` — must be set (today or past for standalone expenses; completion date for task-linked expenses)
- `account_id` — must reference a valid bank account
- `category_id` — must reference a valid category
- `exchange_rate` — must be set if the account's currency differs from the user's `main_currency` in `user_settings` (defaults to 1.0 if same currency). Auto-filled from the `exchange_rates` reference table for the transaction's date; user can override with their actual rate.

If any mandatory field is missing, the expense stays in the inbox. This allows users to capture expenses fast — even just an amount or a title — and fill in the rest later.

**Direct to ledger:** Expenses can bypass the inbox entirely if all mandatory fields are provided at creation time and the date is today or past. The same validation rules apply.

**Categories are flat** — no hierarchy, no parent/child. Every category is directly assignable to transactions. Categories are the primary organizational bucket; totals always add up cleanly because each transaction belongs to exactly one category.

**Hashtags are cross-cutting filters** — many per transaction, freeform. They provide context (e.g., #Vacation, #Dog, #TaxDeductible) without breaking the category structure. In breakdown views (e.g., monthly expense table by category), transactions within a category are grouped by their exact hashtag combination so rows don't overlap and numbers sum to the category total. This grouping is a presentation concern — the database stores individual hashtag links, not combinations.

**Database views** (for efficient reads, not stored data):
- `expense_transaction_inbox_view` — joins inbox items with account, category, and linked task details
- `expense_categories_with_counts` — categories with their transaction counts

### Notes Tables

```
note_entries
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - title (text, NOT NULL, default 'UNTITLED')
  - content (text, nullable) — full markdown content
  - notebook_id (UUID, nullable, foreign key → note_notebooks) — one notebook per note (nullable = note lives in Inbox)
  - is_pinned (boolean, NOT NULL, default false) — pinned notes appear at top of their notebook. Not available for Inbox notes (notebook_id = null).
  - note_date (timestamptz, NOT NULL, default now()) — user-facing display date, auto-generated but modifiable
  - hidden_in_notes_app (boolean, NOT NULL, default false) — when true, note is hidden from Notes app but still accessible via linked expenses/tasks
  - created_at (timestamptz, default now()) — immutable system creation timestamp
  - updated_at (timestamptz, default now()) — updated on every edit, drives sync engine
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - CHECK constraint: (notebook_id IS NOT NULL OR is_pinned = false) — pinning is only valid when a note belongs to a notebook. Inbox notes (notebook_id = NULL) cannot be pinned.

note_notebooks
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - name (text, NOT NULL)
  - color (text, NOT NULL, default '#3b82f6') — UI display color in sidebar
  - sort_order (integer, NOT NULL, default 0)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (user_id, name)

note_hashtags
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - name (text, NOT NULL) — display name, prefixed with `#` in UI
  - sort_order (integer, NOT NULL, default 0) — controls display order in the sidebar
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (user_id, name)

note_entry_hashtags
  - id (UUID, primary key, default uuid_generate_v4())
  - note_id (UUID, NOT NULL, foreign key → note_entries)
  - hashtag_id (UUID, NOT NULL, foreign key → note_hashtags)
  - user_id (UUID, NOT NULL, foreign key → users)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (note_id, hashtag_id)
```

**Three date concepts on notes:**
- `note_date` — the user-facing date displayed as `DD/MM: TITLE` in the timeline. Auto-generated on creation, modifiable by the user (e.g., backdating a thought from yesterday).
- `created_at` — immutable system timestamp. When the record was actually created. Never changes.
- `updated_at` — system timestamp updated on every edit. Drives sync engine and can be shown as "Last edited: 2 hours ago."

**Inbox (virtual view):** Notes with `notebook_id = NULL` appear in a virtual "Inbox" view in the sidebar. Inbox is not a real notebook — it's a query filter (`WHERE notebook_id IS NULL`). Cannot be renamed or deleted. Pinning is not available in Inbox (notes with `notebook_id = NULL` cannot have `is_pinned = true`).

**Objects (virtual view):** A sidebar-level section that lists all entities created from notes via slash commands — all expenses and to-dos spawned across all notes. Queries `entity_links` where `source_type = 'note'` and `link_context IN ('note_created_expense', 'note_created_task')` for the current user, joined to the target tables for display data and to `note_entries` via `source_id` to show which note each object came from. Objects is not a real notebook — it's a live query, always in sync with `entity_links`. Deleted entities do not appear (their `entity_link` is removed on deletion per the standard deletion matrix). The sidebar order is: Inbox, Objects, then user notebooks. Clicking Objects shows the list of all linked entities in the middle panel (with entity type icon, title, key info like amount or due date, and source note). Clicking an item shows its details in the third panel with the cross-app scoped fields, plus an "Open in Expense Tracker" or "Open in To-Do" link for full editing.

**Notebook assignment via title:** Users type `@NotebookName` in the title field (and only the title field) to assign a note to a notebook. The `@` prefix is parsed and stripped from the display title. This is the same `@` syntax used for categories across all three apps — `@Category` in expense and to-do slash commands, `@NotebookName` in note titles. `#` is reserved for hashtags everywhere. Five symbols: `@` for structural assignment (categories, notebooks), `#` for freeform tagging (hashtags), `$` for bank accounts, `/` for people (Expense Tracker) and slash commands (Notes), `+`/`-` for amount sign prefixes.

**Universal Description Model — notes as single source of truth:** There is no `description` or `notes` column on expenses or tasks. All extended text content lives in `note_entries`. When a user writes a description for an expense or task, a `note_entry` is created (with the expense/task's title as the note title and the description text as the note's content), and an `entity_link` connects them. Both apps read from and edit the same `note_entries` record. See the Universal Description Model section above for full details.

**Deletion matrix for cross-app notes:**

| Action | entity_link | note_entries | Expense sees note? | Notes app sees note? |
|---|---|---|---|---|
| Delete only in Notes app | Kept | hidden_in_notes_app = true | Yes | No |
| Delete only in Expense app | Removed | Untouched | No | Yes |
| Delete everywhere (either app) | Removed | deleted_at set | No | No |
| Delete source item (expense/task that originated the note) | Removed | deleted_at set | No | No |

"Delete everywhere" requires a user confirmation warning. Deleting the source item (expense or task) uses the standard deletion warning — no extra warning needed since deleting an item obviously deletes its description. The same rule applies to tasks: deleting a task that originated a note deletes the note everywhere.

**Notebook deletion:** Deleting a notebook deletes all notes in it (`WHERE notebook_id = deleted_notebook_id`). This is the same behavior as deleting a category in the other apps — the bucket and its contents are removed together.

**Export:** Each notebook exports as a single consolidated `.md` file. Notes within the notebook are concatenated, separated by date headers.

**Database views** (for efficient reads):
- `note_entries_with_notebooks` — joins notes with their notebook details via `notebook_id`

### To-Do Tables

```
todo_tasks
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - title (text, NOT NULL, default 'UNTITLED')
  - (description lives in note_entries, linked via entity_links — Universal Description Model)
  - due_date (timestamptz, nullable)
  - priority (integer, NOT NULL, default 0) — 0=none, 1=low, 2=medium, 3=high
  - is_completed (boolean, NOT NULL, default false)
  - completed_at (timestamptz, nullable)
  - is_recurring (boolean, NOT NULL, default false)
  - parent_task_id (UUID, nullable, foreign key → todo_tasks, for one-level subtasks)
  - subtask_mode (enum subtask_mode: 'independent', 'gated', nullable) — only set on parent tasks
  - category_id (UUID, nullable, foreign key → todo_categories) — one category per task, same pattern as expenses
  - created_by (UUID, nullable, foreign key → users) — who created this task. Populated in Phase 6 for org/shared categories; null for personal tasks.
  - assigned_to (UUID, nullable, foreign key → users) — who is responsible for this task. Set manually by any category member. Null = unassigned.
  - sort_order (integer, NOT NULL, default 0) — manual ordering within views and subtask ordering within parent
  - has_financial_data (boolean, NOT NULL, default false)
  - linked_inbox_id (UUID, nullable, foreign key → expense_transaction_inbox) — links to the expense inbox record holding financial data for this task. When has_financial_data = true, the To-Do app reads amount, currency, category from this linked record for display. See Task → Expense generation below.
  - streak_frequency (enum streak_frequency: 'daily', 'weekly', 'monthly', nullable) — if set, streak tracking is enabled for this task. Defines the period boundary for streak calculation. Null means no streak tracking.
  - streak_goal_type (enum streak_goal_type: 'achieve_all', 'reach_amount', nullable) — what "fulfilled" means within a period. 'achieve_all' = binary (did it or didn't). 'reach_amount' = hit a numeric target. Required when streak_frequency is set.
  - streak_goal_value (integer, nullable) — the numeric target for 'reach_amount' goals (e.g., 8 glasses of water). Null for 'achieve_all' goals.
  - streak_recording_method (enum streak_recording_method: 'auto', 'manual', 'complete_all', nullable) — how the user records progress. 'auto' = each tap/swipe adds 1 unit. 'manual' = user enters a number. 'complete_all' = one tap marks the entire goal as done. Required when streak_frequency is set.
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields

todo_recurrence_rules
  - id (UUID, primary key, default uuid_generate_v4())
  - task_id (UUID, NOT NULL, foreign key → todo_tasks)
  - user_id (UUID, NOT NULL, foreign key → users)
  - pattern (enum recurrence_pattern: 'daily', 'weekly', 'specific_days', 'monthly', 'yearly')
      — daily: every N days (interval controls N)
      — weekly: every N weeks on the same weekday as the task due date
      — specific_days: every week (or every N weeks) on specific ISO weekdays (uses days_of_week)
      — monthly: every N months. Either by date (uses day_of_month) or by position (uses week_of_month + days_of_week[0])
      — yearly: every N years on the same month and day as the task due date
  - interval (integer, NOT NULL, default 1) — the N in "every N [units]", e.g., 2 = every 2 weeks
  - days_of_week (integer[], nullable) — ISO weekday numbers (1=Mon … 7=Sun). Used by specific_days and monthly-by-position patterns.
  - day_of_month (integer, nullable) — for monthly-by-date pattern. 1–28 (capped at 28 to avoid Feb edge cases). E.g., 15 = every 15th.
  - week_of_month (integer, nullable) — for monthly-by-position pattern. 1–4 = first through fourth; -1 = last. E.g., week_of_month=2 + days_of_week=[2] = every 2nd Tuesday.
  - anchor (enum recurrence_anchor: 'fixed', 'after_completion', NOT NULL, default 'fixed')
      — fixed: next occurrence follows the original schedule regardless of when the task was actually completed (e.g., pay rent on the 1st — always the 1st, even if paid on the 3rd)
      — after_completion: next occurrence is calculated relative to the completion date (e.g., floss teeth every day — next due 1 day after you last did it, not on a fixed calendar date)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields

todo_categories
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - name (text, NOT NULL)
  - color (text, NOT NULL, default '#3b82f6')
  - sort_order (integer, NOT NULL, default 0)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (user_id, name)

todo_category_members  — Phase 6 (Collaboration)
  - id (UUID, primary key, default uuid_generate_v4())
  - category_id (UUID, NOT NULL, foreign key → todo_categories)
  - user_id (UUID, NOT NULL, foreign key → users) — the invited member
  - invited_by (UUID, NOT NULL, foreign key → users) — who sent the invitation
  - role (enum todo_member_role: 'owner', 'member', NOT NULL, default 'member')
  - joined_at (timestamptz, nullable) — null until invitation is accepted
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable) — soft delete; removing a member sets deleted_at rather than hard-deleting
  - synced_at (timestamptz, nullable)
  - UNIQUE constraint: (category_id, user_id)

todo_hashtags
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - name (text, NOT NULL)
  - sort_order (integer, NOT NULL, default 0) — controls display order in the sidebar
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (user_id, name)

todo_task_hashtags
  - id (UUID, primary key, default uuid_generate_v4())
  - task_id (UUID, NOT NULL, foreign key → todo_tasks)
  - hashtag_id (UUID, NOT NULL, foreign key → todo_hashtags)
  - user_id (UUID, NOT NULL, foreign key → users)
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - deleted_at (timestamptz, nullable)
  - Sync fields
  - UNIQUE constraint: (task_id, hashtag_id)

streak_completions
  - id (UUID, primary key, default uuid_generate_v4())
  - task_id (UUID, NOT NULL, foreign key → todo_tasks)
  - user_id (UUID, NOT NULL, foreign key → users)
  - date (date, NOT NULL) — the calendar date this completion applies to
  - value (integer, NOT NULL, default 1) — progress recorded. For 'auto' recording: incremented by 1 per tap. For 'manual': user-entered amount. For 'complete_all': set to the goal value (or 1 for achieve_all).
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now()) — updated on every write, required for sync tracking
  - version (integer, NOT NULL, default 1) — auto-incremented by trigger on every update, required for delta sync (WHERE version > last_seen) and optimistic locking
  - deleted_at (timestamptz, nullable) — soft delete, required for sync propagation of removals to other devices
  - Sync fields
  - UNIQUE constraint: (task_id, date) — one completion record per task per day. Multiple taps on 'auto' recording UPDATE the existing row (increment value), not INSERT new rows.
```

**Streaks — a feature on tasks, not a separate entity.** Any task can optionally enable streak tracking by setting `streak_frequency`. The "Streaks" section in the To-Do app is a **filtered view** showing all tasks where `streak_frequency IS NOT NULL`, displaying current streak count, today's progress, and goal status. This follows the same pattern as Expense Planning (a filtered view of inbox, not a separate table).

**Streak calculation:** A streak is the count of consecutive periods where the goal was met. The period boundary depends on `streak_frequency`: daily = each calendar day, weekly = Monday–Sunday (hardcoded for now, configurable later via `user_settings`), monthly = calendar month. A period is "fulfilled" when the sum of `streak_completions.value` for that period meets the goal: for `achieve_all`, any value ≥ 1 counts; for `reach_amount`, the sum must reach `streak_goal_value`. Missing a period resets the streak to zero.

**Auto-unachieve:** A scheduled Edge Function (via `pg_cron`) checks all streak-enabled tasks at the end of each period boundary. For daily streaks, it runs at midnight. For weekly, it runs Sunday at midnight. For monthly, it runs on the last day of the month at midnight. If the goal was not met for the ending period, the streak resets — no manual "unachieved" marking needed. The function checks `streak_completions` for the ending period and compares against the goal.

**Mid-streak configuration changes are not allowed.** If a user wants to change any streak configuration (frequency, goal type, goal value, or recording method) on a task with an active streak, they must end the current streak first — effectively creating a "new" streak. The UI prevents editing streak fields while a streak is active. The user must explicitly reset/end the streak before reconfiguring. This avoids ambiguity about whether historical completions count under old or new rules. The streak history (completions log) for the old configuration is preserved — only the streak count resets.

**Streak-enabled tasks can also be recurring and/or expense-generating.** All task features are orthogonal: `is_recurring`, `has_financial_data`, and `streak_frequency` are independent flags. A task like "Gym membership" can be recurring (monthly), generate an expense ($50 @Fitness), and track a streak (monthly, achieve_all) — all at once.

**Subtask rules:** Tasks support one level of nesting only. A subtask cannot have children. Two completion modes on the parent: *independent* (parent can be completed anytime regardless of subtask status) or *gated* (all subtasks must be completed before the parent can be marked done).

**Task → Expense generation:** When a task with `has_financial_data = true` is completed, an Edge Function creates an expense and an `entity_link` connecting the task to it. The flow depends on whether the task has a linked inbox record (`linked_inbox_id`):

**First completion (no linked inbox record):** The Edge Function creates an `expense_transaction_inbox` record using the task's title. The `date` on the newly created inbox record is set to `now()` (the current timestamp at the moment of task completion). This means the record appears in the normal Expense Tracker Inbox immediately after the task is completed, where the user fills in remaining financial details before it auto-promotes to the ledger. Since mandatory fields are missing (amount, bank account, category), the expense goes to inbox (Inbox view). The task's `linked_inbox_id` is set to point to the new inbox record, and the inbox record's `linked_task_id` points back to the task. Since it now has a `linked_task_id`, it appears in Expense Planning (not the Inbox view) when managed from the Expense Tracker. The user fills in the remaining financial fields. If the task is recurring, the inbox record is marked `is_recurring = true` and becomes the persistent template (subsequent occurrences will have date = null for recurring templates).

**Subsequent completions (linked inbox record exists with all financial fields filled):** The Edge Function finds the linked inbox record via `linked_inbox_id`, reads its financial fields (title, amount, bank account, category, exchange rate), and creates an `expense_transactions` record directly in the ledger. The `date` is set to the **task completion date** (current date at moment of completion — not the task's due date). Since all financial fields come from the inbox template, the expense goes straight to ledger with no user intervention. For recurring tasks, the linked task's `due_date` advances to the next occurrence per the recurrence rule. Schedule anchoring is configurable: original schedule or from last completion.

**Title independence:** The task title and the expense title are separate fields on separate tables (`todo_tasks.title` and `expense_transaction_inbox.title`). They start as the same value — on first inbox record creation, the inbox `title` is initialized from the task's `title`. After that, they are fully independent — editing one does not affect the other. The task title is the human-friendly label for the To-Do app ("Restaurant Payment"). The expense title is for the bank statement entry in the Expense Tracker ("IZI*PAY POS TIENDA SUR"). In Expense Planning (before the expense occurs), the primary display label is the **task title** (read from the linked task). Once promoted to the ledger, the expense uses its own `title` from the inbox template.

**Editing individual expenses:** Editing a specific month's generated expense does NOT affect the inbox template. The template represents the "standard" version. One-off changes stay isolated to that expense.

**Changing all future occurrences:** The user edits the inbox template from the Expense Planning section in the Expense Tracker. All future completions use the updated values. The To-Do app shows the restricted cross-app expense fields (amount, currency, category — read from the linked inbox record) plus normal to-do fields (title, due date, recurrence, completed status) — full expense management (bank account, exchange rate, description, expense title) lives in the inbox template, accessible from the Expense Planning section.

**Descriptions on planned expenses:** The inbox template can have a linked note via the Universal Description Model, same as any inbox or ledger record. For recurring expenses, the template's description persists. Each generated ledger expense is a fresh entity and does NOT inherit the template's description — the user adds per-occurrence descriptions manually if needed.

**Expense Planning section in the Expense Tracker:** The Expense Tracker has an "Expense Planning" section that is a **filtered view of the inbox table** — it shows all `expense_transaction_inbox` records that have a `linked_task_id`, sorted by the linked task's `due_date`. For recurring expenses, the inbox template is persistent (one row per recurring expense, date = null, due date displayed from the linked task). For one-off planned expenses, the record exists until registered. Each entry shows the full expense data: title, amount, currency, bank account, category, exchange rate, and description, plus the linked task's due date. The user manages the template here — editing updates the inbox record directly, and all future completions use the new values. The user can **register/confirm** a planned expense when it happens — this completes the linked task, which triggers the inbox → ledger promotion flow.

**Overdue section:** A subset of Expense Planning where the linked task's `due_date` is today or past and the task is not completed. These are planned expenses whose due date has passed without being confirmed. The user can complete them (registers to ledger with the completion date) or reschedule them (update the task's due date).

**Creating planned expenses:** Users create planned expenses through the normal FAB by setting a future date. There is no separate creation form in the Expense Planning section — it is a read-only filtered view plus register/confirm actions. When a user adds an expense with a future date (any date after today) from the FAB, the system creates an `expense_transaction_inbox` record (with `date = null`) and a linked `todo_task` with the future date as its `due_date`. For recurring expenses, a `todo_recurrence_rule` is also created — the task drives the scheduling, the inbox record holds the financial data and is marked `is_recurring = true`. The expense appears in the Expense Planning section. Expenses with today's date or a past date are created normally (inbox or ledger depending on field completeness).

**One occurrence at a time:** For recurring planned expenses, the inbox template is persistent and the linked task shows the next due date. The recurrence engine (via the linked task) calculates when the next occurrence is due. When the user registers/completes it, a ledger entry is generated with the completion date, and the linked task's `due_date` advances to the next occurrence. This keeps the Expense Planning list clean — one row per recurring expense.

**Deleting a recurring expense:** The user is prompted with two options: (1) **Delete this expense only** — deletes the single ledger entry, the recurring template and linked task remain active and continue generating future occurrences. (2) **Delete all future occurrences** — deletes the inbox template and the linked task (including its recurrence rule), stopping all future generation. Previously generated ledger entries are never deleted — they are real financial records. There is no "skip this occurrence" or "pause recurrence" — for future occurrences, the user either keeps or deletes.

**Deleting a task linked to an expense:** If the linked task is deleted from the To-Do app, previously generated expenses survive as standalone ledger entries. For recurring expenses, the inbox template loses its automation (no more task completions trigger ledger entries) and moves to the Inbox view (since it no longer has a `linked_task_id`). The user can manually manage it or re-link a new task from Expense Planning. Deleting the task never deletes prior expenses — they are real financial records.

### Activity Log Table

```
activity_log
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users)
  - action_type (enum action_type: 'created', 'deleted', 'completed', 'modified')
  - entity_type (text, NOT NULL) — e.g., 'expense_transaction', 'note_entry', 'todo_task', etc.
  - entity_id (UUID, NOT NULL) — references the affected record
  - summary_text (text, NOT NULL) — human-readable line, e.g., "Created expense: Lunch at Noma"
  - timestamp (timestamptz, NOT NULL, default now())
  - synced_at (timestamptz, nullable)
```

**Design principles:**

- **Read-only:** Activity entries are never edited or deleted by the user. They are an immutable audit trail.
- **Simple display:** Each entry renders as a single line with day, time, and summary text.
- **Scope:** Logs creates, deletes, completions (tasks only), and everything else as "modified." No granular field-level change tracking — just that something changed.
- **Location:** Each app has its own activity view, filtered by `entity_type`. The activity data lives in the shared `activity_log` table; each app queries only its relevant entries.
- **No `version` or `deleted_at`:** Activity log entries are append-only. They are never updated or soft-deleted.

### The Entity Links Table — Cross-App Glue

The `entity_links` table is how the ecosystem holds together. Every cross-app relationship is a row in this table.

**Examples:**

- An expense has a note → `entity_links` row with source_type='expense_ledger', target_type='note', link_context='expense_note' (use 'expense_inbox' if the expense is still in the inbox)
- A to-do completion generates an expense → `entity_links` row with source_type='task', target_type='expense_ledger', link_context='task_expense'
- A slash command in Notes creates a to-do → `entity_links` row with source_type='note', target_type='task', link_context='note_created_task'

**Deletion behavior:** "Remove from here" soft-deletes the `entity_links` row (sets `deleted_at`). "Delete everywhere" soft-deletes all `entity_links` rows referencing the item, then soft-deletes the item itself. Both propagate to other devices via the standard tombstone sync pattern.

### Slash Commands in Notes

Notes can contain slash commands (`/expense`, `/todo`) that create entities in other apps.

**Slash commands are quick capture tools, not full-featured forms.** They capture the core fields in the note. If the user needs to add more detail (exchange rate, priority, people splits, etc.), they go to the actual app.

**Supported fields:**

- `/expense -30 Lunch yesterday @Food $BCP_PEN` — captures amount (with sign), title, date, category, and bank account. Date supports natural language parsing ("yesterday", "Feb 15", "last Friday"). Since all mandatory ledger fields are present (amount, title, date, bank account, category), this goes directly to the ledger if the date is today or past. If the date is in the future, future-date routing applies (creates inbox record + linked task).
- `/todo Buy groceries tomorrow @Personal #Errands` — captures title, date, category, and hashtag. Date supports natural language parsing.

**Execution model — confirmation before creation:** When the user types a slash command and hits Enter, the entity is NOT created immediately. Instead, the raw command text transforms into an **inline preview card** showing the parsed fields (amount, title, date, category, bank account for expenses; title, date, category, hashtag for to-dos). The preview card has a "Confirm" button and an "X" (cancel) button. The entity is only created when the user taps Confirm. If the user cancels or deletes the preview line, nothing is created — no phantom entities. This prevents the problem of accidental duplicate entities when the user types a command wrong, deletes it, and retypes it. The preview also gives the user a chance to verify that natural language parsing interpreted the fields correctly (e.g., "yesterday" parsed as the right date).

**Storage model — HTML comment markers:** When a slash command is processed, the raw command text in the note's `content` field is replaced with an HTML comment marker containing the entity type and UUID:

- Expense: `<!--expense:550e8400-e29b-41d4-a716-446655440000-->`
- To-do: `<!--todo:550e8400-e29b-41d4-a716-446655440000-->`

The note's `content` remains valid markdown (HTML comments are valid markdown). The app's markdown renderer recognizes these markers and renders them as styled displays. The actual entity data (amount, title, completion state, etc.) is fetched from the database at render time using the UUID — the note content only stores the reference, not the data. This means the display stays current even if the entity is edited in its source app.

**Parsing:** The app scans content with a regex pattern (`<!--(expense|todo):([a-f0-9-]+)-->`) to find all embedded entity references. Each marker sits on its own line in the content.

**Relationship tracking:** The `entity_links` table tracks all note-to-entity relationships (via `note_created_expense` and `note_created_task` contexts). This handles reverse lookups ("which notes reference this expense?") without needing to scan note content. The markers in the content are for rendering only.

**Deleted entity handling:** If a linked entity is deleted, the marker stays in the content but the renderer shows a "deleted" state — greyed out or red with a crossed-out style that is visually distinct from regular markdown strikethrough (`~~text~~`). Non-interactive, no link. The `entity_link` is removed per the standard deletion matrix. The renderer checks: if the UUID doesn't resolve to a live entity, show the deleted state. The user can manually remove the marker line from the note if they want to clean it up.

**Display behavior:**

- Expense markers render as a static styled line: `-30.00 Lunch` with a link to the expense. The command syntax is hidden; only the clean display is shown. Not interactive (no inline editing of the expense).
- To-do markers render as an interactive checkbox: `[ ] Buy groceries` with a styled date tag showing `Tomorrow` (or the relevant date) in a distinct color/badge. The checkbox is functional — checking it marks the linked `todo_task` as complete.
- A single note can contain multiple slash commands (mix of expenses and to-dos), each on its own line as a separate HTML comment marker.

**Bidirectional sync for to-do checkboxes:**

When a `/todo` command creates a task, the checkbox in the note and the `is_completed` field on the `todo_task` stay in sync:

- Checking the checkbox in the note → marks the `todo_task` as complete (sets `is_completed = true`, `completed_at = now()`)
- Completing the task in the To-Do app → updates the checkbox in the note to checked
- Unchecking works in both directions as well

This is handled through the `entity_link` connecting the note to the task. When either side changes, the sync engine propagates the completion state to the other.

**Slash command → expense routing:** `/expense` commands capture all mandatory ledger fields (amount, title, date, bank account, category). If the date is today or past, the expense can auto-promote directly to the ledger — no inbox stop needed. If the date is in the future, future-date routing applies (creates an inbox record with `date = null` and a linked `todo_task` with the future date as `due_date`). If any field is omitted from the command, the expense goes to the inbox for the user to complete.

## Row Level Security

Every table has a Supabase RLS policy:

```sql
-- Applied to every table
CREATE POLICY "Users can only access their own data"
ON [table_name]
FOR ALL
USING (user_id = auth.uid());
```

**Additional RLS for shared expenses:**

```sql
-- expense_transactions: receiver can READ transactions shared with them
CREATE POLICY "Receivers can read shared transactions"
ON expense_transactions
FOR SELECT
USING (
  id IN (
    SELECT transaction_id FROM transaction_shares
    WHERE user_id = auth.uid() AND deleted_at IS NULL
  )
);

-- transaction_shares: receiver can read/write their own share rows
CREATE POLICY "Users can access their own shares"
ON transaction_shares
FOR ALL
USING (user_id = auth.uid());
```

Receiver **writes** to `expense_transactions` (editing lockable fields before confirmation) go through a database function that enforces the confirmation/locking logic — not through direct table writes.

This ensures data isolation at the database level. No application code needed to filter by user.

## Sync Engine

### Core Principles

1. **Local-first:** the UI reads from and writes to the local SwiftData store. Network operations happen in the background.
2. **Optimistic UI:** changes appear instantly in the UI. The sync engine pushes them to Supabase afterward.
3. **Version-based delta sync:** pull changes using monotonic version numbers (`WHERE version > p_since_version`), not timestamps. Clock-independent — no timezone or clock-skew issues across devices.
4. **Record-level last-write-wins:** when two devices edit the same record, the higher version wins the entire record. No per-field merging. Simple, proven, and sufficient — this is the same approach Todoist uses at scale.
5. **Soft deletes:** records are marked with a `deleted_at` timestamp and synced. Actual row deletion happens via scheduled cleanup.

### Sync Fields on Every Record

Every mutable table includes these columns:

```
- id (UUID, generated locally on creation)
- updated_at (timestamptz, when any field was last modified)
- synced_at (timestamptz, nullable, last confirmed sync with server)
- deleted_at (timestamptz, nullable, soft delete — NULL means active)
- version (integer, default 1, auto-incremented on every update via database trigger)
```

The `version` column serves dual purpose: it drives delta sync (what changed?) AND optimistic concurrency (prevent stale overwrites). A sync push includes the expected version, and the server rejects the update if the version has changed.

### Sync Flow

**On app launch:**

1. Read from local SwiftData → UI renders immediately
2. Background: pull changes from Supabase with `WHERE version > p_since_version ORDER BY version LIMIT 500`
3. For each incoming record: if remote version > local version, replace the local record entirely (record-level last-write-wins)
4. Push local pending changes to Supabase (two-phase push — see below)
5. Update `synced_at` on all successfully pushed records
6. Subscribe to Supabase real-time channel for live updates

**On local write:**

1. Write to SwiftData immediately → UI updates
2. Mark record as `pending` sync
3. Sync engine pushes to Supabase in background
4. On success: update `synced_at`, mark as `synced`
5. On conflict (version mismatch): server version wins, local record is overwritten
6. On network failure: retry with exponential backoff, change stays in queue

**On real-time update received:**

1. Compare incoming version with local version
2. If remote version > local version: replace local record, UI updates reactively
3. If local version >= remote version: ignore (local is already up to date or has pending changes)

**On deletion:**

1. Set `deleted_at = now()` locally → UI removes the item
2. Sync engine pushes the soft delete to Supabase
3. Other devices receive the soft delete via real-time and hide the item
4. Tombstone cleanup: a Supabase `pg_cron` job runs daily, pruning tombstoned records older than 30 days

### Two-Phase Push

Sync pushes use a PRUNE-then-PLANT approach to prevent constraint violations:

1. **PRUNE phase (deletes first):** push all soft-deletes before any creates or updates. This prevents race conditions like delete-then-recreate with the same unique constraint (e.g., delete an account named "Chase" and create a new one named "Chase").
2. **PLANT phase (upserts second):** push creates and updates in foreign key dependency order: `bank_accounts → categories → budgets → user_settings → transactions → inbox → reconciliations → streak_completions`. This ensures parent records exist before children reference them.

### Per-Item Isolation in Batch Sync

Batch sync operations use per-item SAVEPOINTs in database RPCs:

- Each record in a batch gets its own `BEGIN...EXCEPTION...END` block
- One bad record does NOT fail the entire batch
- Returns `{ synced_ids, conflict_ids, error_map }` for granular feedback
- The UI can show which records synced and which have conflicts

### Write-Then-Read Pattern

When a mutation triggers database logic (balance recalculation, version auto-increment, `updated_at` refresh), never trust the INSERT/UPDATE return value. Instead:

1. Write to the table (INSERT or UPDATE)
2. Database trigger updates `version`, `updated_at`, and any computed fields (e.g., `current_balance_cents`)
3. Immediately SELECT from the view (which JOINs enrichment data like account name, currency symbol)
4. Return the complete, trigger-updated record to the caller

This ensures the client always has the correct version number and computed values after every mutation.

### Balance Trigger

The `current_balance_cents` trigger on `expense_bank_accounts` handles all lifecycle states:

| Case | Condition | Balance Action |
|---|---|---|
| Physical DELETE | Record was active | Subtract from account |
| INSERT (active) | `deleted_at IS NULL` | Add to account |
| Soft-delete | Was active → tombstoned | Subtract OLD amount |
| Restore | Was tombstoned → active | Add NEW amount |
| Update while tombstoned | Both `deleted_at` set | No-op |
| Update while active | Amount or account changed | Adjust delta |

### Mutation Locking

When a record is being synced, local mutations to that record are buffered (not rejected):

- The UI receives projected data for optimistic display
- Queued mutations are applied after the sync cycle completes
- This prevents the UI from blocking during active sync

### Offline Handling

The app works fully offline. All changes write to local SwiftData and are marked as `pending`. When connectivity returns, the queue is processed via two-phase push. The user sees no difference in behavior — the only indicator might be a subtle sync status icon.

### Initial Sync

On first launch after sign-in, the app pulls all records for the authenticated user from Supabase (full sync) and populates the local SwiftData store. Subsequent syncs are delta-only using version numbers. An early-exit optimization checks if any changes exist before pulling (~10ms) — if no changes, skip the pull entirely.

### Repository Pattern

All data access goes through repository interfaces. The app's business logic and UI never know whether data comes from local storage or the remote server. Each entity type has its own repository:

- `ExpenseRepository` — handles expense_transactions, expense_transaction_inbox
- `BankAccountRepository` — handles expense_bank_accounts
- `CategoryRepository` — handles expense_categories (flat, no hierarchy)
- `ReconciliationRepository` — handles expense_reconciliations
- `BudgetRepository` — handles expense_budgets (monthly per-category budget templates, enforcement of all-or-nothing rule when budget_enabled)
- `NoteRepository` — handles note_entries
- `NotebookRepository` — handles note_notebooks
- `NoteHashtagRepository` — handles note_hashtags, note_entry_hashtags
- `TaskRepository` — handles todo_tasks, todo_recurrence_rules (future)
- `StreakRepository` — handles streak_completions, streak calculation logic (current streak count, period fulfillment checks)
- `HashtagRepository` — handles expense_hashtags, todo_hashtags, and their junction tables
- `BankAccountRepository` — handles expense_bank_accounts (both real accounts and person accounts with `is_person = true`)
- `ExchangeRateRepository` — handles exchange_rates (rate lookups by date with fallback to most recent, deriving cross-currency rates through USD)
- `TransactionShareRepository` — handles transaction_shares (cross-user shared expense visibility, confirmation state, receiver categories)
- `EntityLinkRepository` — handles entity_links (cross-app references)
- `SubscriptionRepository` — handles user_subscriptions (read-only on client, updated via Apple webhook)
- `ActivityLogRepository` — handles activity_log (append-only on client, read-only display)

Each repository follows the same contract:
1. **Read** — always from local SwiftData first (instant)
2. **Write** — always to local SwiftData first (optimistic UI), then queued for sync
3. **Sync** — the repository's sync layer handles pushing to Supabase and merging incoming changes
4. **Observe** — SwiftUI views observe the local SwiftData store reactively; changes from sync automatically update the UI

The repository abstracts away all sync complexity. A view calling `noteRepository.create(note)` doesn't know or care about sync queues, conflict resolution, or network state. This separation means the sync engine can be improved or replaced without touching any business logic or UI code.

### Tombstone Pattern

Deletions are propagated across devices using tombstones — soft-delete markers that sync like any other change.

**How it works:**
1. User deletes a record → `deleted_at` is set to the current timestamp (the tombstone)
2. The record stays in the local SwiftData store and in Supabase, but is hidden from all UI queries
3. The tombstone syncs to other devices via the normal sync flow
4. Other devices receive the tombstone, set `deleted_at` locally, and hide the record
5. A periodic Supabase cleanup function (Edge Function on a cron schedule) purges tombstoned records older than a configurable retention period (e.g., 30 days) — only after all known devices have confirmed the deletion

**Why tombstones instead of hard deletes:**
- Hard deletes can't sync — if Device A deletes a record and Device B doesn't know about it, Device B will re-create the record on next sync push
- Tombstones propagate through the normal sync flow without special handling
- The retention period allows recovery of accidentally deleted data within the window
- The `deleted_at` timestamp provides an audit trail of when deletions occurred

**Tombstone queries:** All repository read operations include `WHERE deleted_at IS NULL` by default. Tombstoned records are invisible to the application unless explicitly queried (e.g., for a "recently deleted" recovery feature).

## Database Indexes

Indexes are defined in migration files alongside the table definitions. These are the required indexes based on the system's actual query patterns.

**Universal indexes (every per-user table):**
- `(user_id)` — every query filters by user; without this, Postgres scans the entire table
- `(user_id, deleted_at)` — the most common read query shape: non-deleted records for a user
- `(user_id, version)` — delta sync query: `WHERE user_id = ? AND version > last_seen_version`

**Table-specific indexes:**

| Table | Index | Reason |
|---|---|---|
| `expense_transactions` | `(user_id, date DESC)` | Transaction list sorted by date |
| `expense_transactions` | `(account_id)` | Sidebar balance aggregation per account |
| `expense_transactions` | `(category_id)` | Sidebar balance aggregation per category |
| `expense_transactions` | `(reconciliation_id)` | Fetching all transactions in a reconciliation batch |
| `expense_transaction_inbox` | `(user_id, created_at DESC)` | Inbox list sorted by creation date |
| `todo_tasks` | `(user_id, due_date)` | Today/Upcoming tab queries filter by date |
| `todo_tasks` | `(user_id, category_id)` | Filtering tasks by category |
| `todo_tasks` | `(parent_task_id)` | Fetching subtasks for a given parent |
| `todo_tasks` | `(user_id, is_completed, due_date)` | Composite for Today/Upcoming tab (non-completed, date-filtered) |
| `note_entries` | `(user_id, notebook_id)` | Fetching notes in a notebook |
| `note_entries` | `(user_id, is_pinned)` | Fetching pinned notes |
| `entity_links` | `(source_id, source_type)` | Looking up all links from a given source entity |
| `entity_links` | `(target_id, target_type)` | Looking up all links pointing to a given entity |
| `exchange_rates` | `(base_currency, target_currency, rate_date)` | Already covered by UNIQUE constraint |
| `todo_category_members` | `(user_id)` | Finding all categories a user is a member of |

**Notes:**
- The UNIQUE constraint on `exchange_rates (base_currency, target_currency, rate_date)` automatically creates a B-tree index — no separate index needed.
- The UNIQUE constraint on `todo_category_members (category_id, user_id)` similarly creates an index automatically.
- Indexes on `deleted_at` alone are not needed — the composite `(user_id, deleted_at)` covers the filter pattern.
- All indexes are created with `CREATE INDEX IF NOT EXISTS` in migration files for idempotency.

## Authentication

**Provider:** Supabase Auth.

**Launch auth method:** Sign in with Apple (required for iOS apps with third-party auth). Additional methods (email/password, Google Sign-In) will be added as the platform expands.

### Sign in with Apple — Important Caveat

Apple only provides the user's name and email address **on the very first sign-in**. On every subsequent sign-in, Apple returns only the identity token (the stable `sub` identifier). This is a hard Apple platform constraint, not a Supabase limitation.

**Consequence for iOS implementation:** The app must save the user's name locally (e.g., `UserDefaults` in the App Group container) *before* making the Supabase auth call. If the name is saved after the network call and the call fails, the name is lost permanently for that user. The correct sequence is:

1. Receive Apple credential from `ASAuthorizationAppleIDCredential`
2. Immediately save `fullName` (given + family) to `UserDefaults` in the App Group container
3. Call `supabase.auth.signInWithIdToken(...)` with the identity token
4. On successful auth, write the saved name to the `users` table via a profile upsert call
5. Clear the saved name from `UserDefaults`

## Authentication Flow

1. User taps "Sign in with Apple" in any of the three apps
2. Apple presents the native auth sheet; user authenticates with Face ID / Touch ID / password
3. Apple returns an `ASAuthorizationAppleIDCredential` containing the identity token (JWT) and, on first sign-in only, the user's name and email
4. App saves the name immediately (step 2 of iOS implementation above)
5. App calls `supabase.auth.signInWithIdToken(provider: .apple, idToken: ...)` — Supabase verifies the token with Apple's public keys and creates or returns the existing `auth.users` row
6. A PostgreSQL trigger fires on `auth.users` insert and creates the corresponding `public.users` row (see trigger below)
7. The Supabase session (access token + refresh token) is stored in the iOS Keychain, scoped to the App Group so all three apps share it
8. All Supabase SDK calls automatically attach the access token; RLS policies use `auth.uid()` to enforce per-user data isolation
9. On first sign-in, a `user_settings` row and a `user_subscriptions` row are created with defaults (via the same trigger or a follow-up upsert)
10. App reads the saved name from `UserDefaults`, upserts it to `public.users.display_name`, then clears `UserDefaults`

### DB Trigger — Populating `public.users`

Supabase Auth manages `auth.users` internally. The app never writes to `auth.users` directly. A trigger bridges from `auth.users` to `public.users` on first sign-in:

```sql
-- Trigger function: runs whenever a new row is inserted into auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
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

  -- Create default user_settings row
  INSERT INTO public.user_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Create default user_subscriptions row (trialing)
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

-- Attach trigger to auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

The `display_name` fallback uses `raw_user_meta_data->>'full_name'` because Supabase copies Apple's provided name into that field on first sign-in. The email prefix fallback handles edge cases where Apple provides a relay email. The iOS app always upserts the actual name as a follow-up write after sign-in succeeds (step 10 above), so the fallback is a safety net, not the primary path.

### Row-Level Security (RLS)

All user-owned tables have RLS enabled. The canonical policy pattern:

```sql
-- Users can only read their own rows
CREATE POLICY "Users can read own data" ON expense_transactions
  FOR SELECT USING (auth.uid() = user_id);

-- Users can only insert rows for themselves
CREATE POLICY "Users can insert own data" ON expense_transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own rows
CREATE POLICY "Users can update own data" ON expense_transactions
  FOR UPDATE USING (auth.uid() = user_id);
```

`auth.uid()` is a Supabase-provided function that returns the UUID of the currently authenticated user from the JWT. Every query automatically filters to the authenticated user's data without any application-level `WHERE user_id = ?` guard being required — though Repository methods also include it explicitly for clarity and defence-in-depth.

**Service role key:** The DB trigger function and Edge Functions run with `SECURITY DEFINER` or the Supabase service role key, which bypasses RLS. These are backend-only paths; the iOS app never uses the service role key.

### Shared Auth via App Group

Signing into one app signs the user into all three. The Supabase session lives in the shared Keychain group (`group.com.warmproductivity.shared`). The Supabase iOS SDK is configured to use this Keychain group on initialisation:

```swift
// In SupabaseClient package — shared configuration
let supabase = SupabaseClient(
    supabaseURL: URL(string: supabaseURL)!,
    supabaseKey: supabaseAnonKey,
    options: SupabaseClientOptions(
        auth: AuthClientOptions(
            storage: KeychainLocalStorage(
                accessGroup: "group.com.warmproductivity.shared"
            )
        )
    )
)
```

This means a user who signs in via Expense Tracker is already authenticated when they open Notes or To-Do — no second sign-in prompt.

## Subscription & Payments

**Model:** Freemium with a 1-month free trial, then paid subscription tiers.

**Payment provider:** Apple In-App Purchases (StoreKit 2) for iOS. Platform-appropriate payment methods added as new platforms launch.

### Subscription Schema

```
user_subscriptions
  - id (UUID, primary key, default uuid_generate_v4())
  - user_id (UUID, NOT NULL, foreign key → users, UNIQUE) — one row per user
  - product_id (text, nullable) — StoreKit product identifier from App Store Connect (e.g., 'warm_productivity_monthly')
  - plan_tier (enum plan_tier: 'free', 'pro', NOT NULL, default 'free') — app's internal tier concept
  - status (enum subscription_status: 'trialing', 'active', 'grace_period', 'billing_retry', 'expired', 'cancelled', 'revoked', NOT NULL, default 'trialing')
  - auto_renew_enabled (boolean, NOT NULL, default true)
  - trial_start_date (timestamptz, nullable) — when the 1-month free trial began
  - trial_end_date (timestamptz, nullable) — when the trial expires
  - current_period_start (timestamptz, nullable) — start of the current billing period
  - current_period_end (timestamptz, nullable) — end of current billing period (key date for feature gating)
  - grace_period_end (timestamptz, nullable) — Apple's grace window for failed payments, user retains access
  - cancellation_date (timestamptz, nullable) — when the user cancelled
  - original_transaction_id (text, nullable) — Apple's unique identifier for the subscription chain, stable across renewals
  - environment (enum subscription_environment: 'sandbox', 'production', NOT NULL, default 'production')
  - platform (text, NOT NULL, default 'ios') — future-proofed for 'macos', 'stripe', etc.
  - created_at (timestamptz, default now())
  - updated_at (timestamptz, default now())
  - version (integer, NOT NULL, default 1)
  - Sync fields
```

**Single-row approach:** Each user has exactly one row, updated in place as status changes. The row always reflects current subscription state. No history tracking — if analytics on churn or resubscription patterns are needed later, a separate `subscription_events` table can be added without changing this schema.

**Lifecycle:** On first sign-in, a `user_subscriptions` row is created with `status = 'trialing'`, `trial_start_date = now()`, `trial_end_date = now() + 1 month`. When the trial ends, if no payment method is on file, status moves to `expired`. If the user subscribes, status moves to `active` with `current_period_start` and `current_period_end` set.

**Apple integration:** A Supabase Edge Function receives App Store Server Notifications V2 as a webhook. When Apple sends a notification (subscription, renewal, cancellation, billing issue, grace period, revocation), the Edge Function updates the `user_subscriptions` row. The app never handles payment state directly — it reads from this table.

**Feature gating:** Read the user's subscription row. If `status` is 'trialing' or 'active' and the relevant period hasn't ended, full access. If `status` is 'grace_period' and `grace_period_end` hasn't passed, full access. Otherwise, restrict to free tier. Enforced both client-side (UI) and server-side (RLS policies or Edge Function checks) to prevent bypassing.

**Tier structure and feature gating details** to be defined as the product matures. The architecture supports arbitrary tier definitions without schema changes.

## API Layer

**Direct Supabase SDK** for simple operations:

- Fetching records (expenses, notes, tasks)
- Simple creates and updates
- Real-time subscriptions

**Edge Functions** for complex operations:

- **Expense from task completion:** creates the expense_transaction, creates the entity_link, updates the task — all in one atomic transaction
- **Inbox promotion (no linked task):** triggered when the user taps the Promote button on a ready inbox item. Validates all mandatory fields are present (title, amount, bank account, category, date) and date is today/past. Exchange rate auto-fills and never blocks promotion. Inserts into `expense_transactions` (ledger), deletes inbox record, updates entity_links.
- **Task completion promotion:** triggered when a linked task is completed. Copies financial data from the linked inbox record. Updates any existing `entity_links` pointing to the inbox record to target the new ledger record. For one-off (`is_recurring = false`): inserts into `expense_transactions` with completion date as `date`, deletes inbox record, updates entity_links. For recurring (`is_recurring = true`): inserts into `expense_transactions` with completion date as `date`, keeps inbox record (template), creates new entity_link for the ledger entry, advances linked task's `due_date` to next occurrence per recurrence rule and schedule anchoring setting.
- **Planned expense creation:** creates `expense_transaction_inbox` record (with financial fields, `date = null`) and linked `todo_task` with `due_date` (+ `todo_recurrence_rule` if recurring) when user adds a future-dated expense via the FAB.
- **Reconciliation management:** creates/completes/un-reconciles batches. On batch completion: sets status to `completed`, locks `amount_cents`, `account_id`, `title`, and `date` on all included transactions. On un-reconcile: reverts status to `draft`, unlocks those four fields. Transaction assignment to batches (setting/clearing `reconciliation_id`) is handled by direct updates from the transaction menu, not this function.
- **Split generation:** when an expense is tagged with `/PersonName +amount` (e.g., `/Eliana +20`), auto-generates @Debt transactions on each person's virtual account. Creates person and virtual account if they don't exist. Runs atomically alongside the source expense creation.
- **Streak auto-unachieve:** scheduled via `pg_cron`. Runs at period boundaries (midnight daily, Sunday midnight weekly, last day of month monthly). For each streak-enabled task, checks if the ending period's `streak_completions` meet the goal. If not, the streak resets. No records are created for missed periods — the absence of a fulfilling `streak_completions` entry IS the failure signal. Streak count is always calculated from the completions log, not stored as a field.
- **Paired transaction creation:** parses the `/` syntax, creates linked expense_transactions with the same transfer_id, applies category rules (user's category + @Debt for people, @Other for inter-account transfers), auto-creates person accounts in new currencies when needed. If the target person account has `linked_user_id`, automatically creates a `transaction_shares` row for the linked user.
- **Shared expense edit gatekeeper:** database function that handles all edits to shared transactions (transactions with a `transaction_shares` row). Enforces confirmation/locking logic: rejects edits to lockable fields when both parties have confirmed; resets the other party's confirmation when one party edits a lockable field. Both originator and receiver edits go through this function.
- **Balance recalculation:** updates `current_balance_cents` on bank accounts (triggered by transaction changes)
- **Slash command processing:** parses the command, creates the target entity, creates the entity_link
- **Notebook deletion:** deletes the notebook and all notes in it (`WHERE notebook_id = deleted_notebook_id`) in one transaction
- **Exchange rate refresh:** (future) daily cron job fetching the previous day's rates from frankfurter.app, writing to `exchange_rates` table with `base_currency = 'USD'`. Phase 1 uses manually maintained rates. Fallback: if no rate for a date, app uses most recent available rate.
- **Main currency change recalculation:** triggered when user changes `main_currency` in `user_settings`. Iterates all transactions, recalculates `exchange_rate` and `amount_home_cents` per the rules in the Exchange Rates section (regular expenses use reference table; cross-currency transfers use implied rates when main_currency matches one leg).
- **Subscription validation:** validates App Store receipts, updates user_subscriptions

## Exchange Rates

### Core Principles

1. **Original amount is immutable.** Every transaction stores `amount_cents` in the account's native currency. This never changes regardless of display settings.
2. **Display conversion is derived, not stored.** `amount_home_cents` and `exchange_rate` on transactions are cached display values that convert to the user's `main_currency`. They are recalculated when `main_currency` changes, or immediately when the user manually edits the `exchange_rate` field on a transaction (`amount_home_cents = amount_cents × new exchange_rate`). A transaction stays permanently bound to whichever exchange rate was used at entry — global rate table updates never retroactively modify existing records.
3. **Single-base reference table.** The `exchange_rates` table stores all rates relative to USD: `1 USD = X target_currency`. To convert between two non-USD currencies (e.g., PEN→HKD), derive through USD: `(PEN→USD) * (USD→HKD)` = `(1/PEN_rate) * HKD_rate`. This means only N-1 rows per day (one per non-USD currency).
4. **User-overridable per-transaction rate.** The reference table provides a default suggestion when creating a transaction. The user can override it because real-world rates vary by vendor (street exchange, bank, app — all different). The user sees a single "Exchange rate" field and can edit it or leave it.

### Reference Table

The `exchange_rates` table holds daily reference rates. `base_currency` is always `USD`. Each row represents: `1 USD = [rate] [target_currency]` on a given date.

**Supported currencies (launch):** USD, PEN. More currencies added over time via the `global_currencies` table.

**Fallback rule:** If no rate exists for a given date, the app uses the most recent available rate for that currency pair. The app never fails to convert — it uses slightly stale data rather than showing an error.

**Phase 1 (manual):** Exchange rates are manually populated by the user via the app or directly in the database. This is sufficient for launch with PEN + USD support. The schema is ready for automation — no changes needed when the switch happens.

**Future (automated):** A Supabase Edge Function on a daily cron schedule fetches the previous day's rates from `api.frankfurter.app` (free, no API key, backed by the European Central Bank) and writes them to the `exchange_rates` table. If the API is down for a day, the fallback rule applies (most recent available rate). For personal expense tracking, yesterday's rates are sufficient.

### Per-Transaction Exchange Rate

Every transaction has an `exchange_rate` field that converts from the account's currency to the user's `main_currency`. This field is:

- **Auto-filled** from the reference table when the transaction is created (derived through USD if neither currency is USD)
- **User-overridable** — the user can type a different rate if their actual rate differs from the reference
- **Set to 1.0** when the account currency matches `main_currency` (no conversion needed)

`amount_home_cents` = `amount_cents * exchange_rate` — a cached display value, always derivable.

### Recalculation on Main Currency Change

When the user changes their `main_currency` in `user_settings`, every transaction's `exchange_rate` and `amount_home_cents` must be recalculated. The logic depends on whether the transaction is part of a cross-currency transfer:

**Regular expenses** (no `transfer_id` linking to a transaction on a different-currency account):
- Recalculate `exchange_rate` from the reference table for the new currency pair (account currency → new main_currency), using the rate for the transaction's date (with fallback to most recent available rate)
- Recalculate `amount_home_cents` = `amount_cents * new exchange_rate`
- Any previous user override is lost — the manual rate was specific to the old currency pair and is meaningless for the new one

**Cross-currency transfers** (has `transfer_id` linking to a transaction on an account with a different `currency_code`):

The two legs of a cross-currency transfer have real, immutable amounts (e.g., -10 PEN and +3.40 USD). The implied transfer rate between them (3.40/10 = 0.34 PEN→USD) is a financial fact — derivable from the two amounts, never stored as a separate field.

When `main_currency` changes:

| Main currency matches... | What happens |
|---|---|
| **One of the two legs** (e.g., main = USD, legs are PEN and USD) | The leg already in main_currency needs no conversion (`exchange_rate` = 1.0). The other leg uses the **implied transfer rate** derived from the two amounts — so the transfer nets to zero on the dashboard. This preserves the financial truth: you moved money between your own accounts, not created or lost value. |
| **Neither leg** (e.g., main = HKD, legs are PEN and USD) | Both legs recalculate `exchange_rate` from the reference table for their respective currency pair (PEN→HKD and USD→HKD). The implied transfer rate between the two legs is unaffected — it's always derivable from the immutable amounts. |

**Why transfers net to zero:** If you transferred 10 PEN → 3.40 USD and your main_currency is USD, the dashboard should show: `-3.40 USD` (PEN leg, converted at implied rate) and `+3.40 USD` (USD leg, already in main_currency) = net zero. Using the reference table rate instead would create phantom gains or losses (e.g., reference rate might convert 10 PEN to 2.70 USD, showing a net +0.70 that doesn't exist).

**Detecting cross-currency transfers:** A transaction is part of a cross-currency transfer when it has a `transfer_id` AND the linked transaction (sharing the same `transfer_id`) is on an account with a different `currency_code`. Same-currency transfers (e.g., moving USD between two USD accounts) don't need special handling — both legs are already in the same currency.

### Deriving Rates Through USD

To convert between two non-USD currencies (e.g., PEN→HKD):

1. Look up `USD→PEN` rate (e.g., 3.75) and `USD→HKD` rate (e.g., 7.82) for the transaction's date
2. `PEN→HKD` = `(1/3.75) * 7.82` = `2.085`
3. `PEN→USD` = `1/3.75` = `0.267`
4. `HKD→USD` = `1/7.82` = `0.128`

All conversions derive from the same N-1 rows in the reference table. No need to store explicit pairs for every combination.

## File Storage (Receipt Photos)

- Photos are uploaded to Supabase Storage (S3-backed)
- The `expense_transactions` table stores only a reference URL
- On the device where the photo was taken, it's cached locally for instant access
- On other devices, photos download lazily in the background
- Photos are scoped to the user's auth ID in Supabase Storage, matching RLS isolation

## Data Export

**Primary format:** CSV per table.

Each app provides an "Export" option (Step 12 — cross-app UI integration) that generates CSV files for its tables. For a full ecosystem export, a ZIP file containing all CSVs.

The Expense Tracker supports CSV import in Phase 1, enabling users to bring in data from other tools.

## Versioning & Migrations

### Schema-First Deployment

The complete database schema for all three apps is deployed from the start — all tables, all columns, all constraints, all relationships. Even features that won't have UI for months have their data model in place from day one. This means the initial Supabase migration contains the full schema defined in this document.

The UI is built in thin slices on top of this stable schema. Each slice exercises a subset of the schema (the core flow first, then secondary features). The schema does not change between UI slices — it's already complete. This eliminates mid-development migrations and ensures the data model is validated before any UI depends on it.

### Cloud (Supabase)

- SQL migration files in the `supabase/migrations/` directory, numbered sequentially
- Applied via the Supabase CLI
- The initial migration deploys the complete schema; subsequent migrations are for schema evolution as the product grows beyond its initial design

### Local (SwiftData)

- SwiftData handles lightweight migrations automatically (adding fields, adding tables)
- Destructive changes (renaming, removing, restructuring) require custom migration mappings
- **Key rule: never delete or rename a column, only add.** Deprecated fields stay in the schema but stop being used. This keeps local migrations automatic in almost all cases.

### Coordination Strategy

- Cloud migrations deploy first (before the app update is released)
- The new app version expects the new schema to exist on the server
- Old app versions continue to work because columns are only added, never removed
- This is forward-compatible by design

## Extension Points

Adding a new app to the ecosystem (e.g., a Calendar, Journal, or Reading List):

**Codebase setup:**

1. Create a new directory under `Apps/` with its own Xcode project
2. Import shared packages: SharedModels, SyncEngine, SupabaseClient, SharedUI
3. Define app-specific SwiftData models with sync fields
4. Write corresponding Supabase migrations for new tables (prefixed with app name)

**Ecosystem integration:**

5. Add the app to the shared App Group for local data access
6. Share the auth session via the shared Keychain group
7. Add entity_link contexts for any cross-app relationships
8. Follow the Universal Description Model if the new app's entities support descriptions
9. Write to `activity_log` for creates, deletes, completions, and modifications
10. Create app-specific repositories following the repository pattern contract (read local, write local, sync background, observe reactively)
11. Follow the established patterns for sync, conflict resolution, and RLS
12. Optionally add a new `/command` in the Notes app for creating entities in the new app

The architecture is designed so that adding a new app requires zero changes to existing apps — it plugs into the shared data layer and the entity_links table handles all cross-app references.

For a practical walkthrough of every integration point organized by app pair, see the Cross-App Integration Map.

## Privacy & Security

This is a product handling users' financial data. Security is non-negotiable.

- **Data isolation:** RLS enforces that users can only access their own data at the database level.
- **Encryption in transit:** all communication over HTTPS/WSS (handled by Supabase).
- **Encryption at rest:** Supabase encrypts data at rest by default (AES-256).
- **Local data:** SwiftData store protected by iOS Data Protection (encrypted when device is locked).
- **Auth tokens:** stored in iOS Keychain (hardware-backed security).
- **Receipt photos:** stored in user-scoped Supabase Storage buckets, accessible only via authenticated requests.
- **Data deletion:** users can request full account and data deletion (required by App Store guidelines). An Edge Function handles cascading deletion across all tables.
- **Privacy policy and terms of service:** required before public launch.

## Future Platform Considerations

**Platform roadmap:** iOS → macOS → Windows → Browser. Android is not currently planned but the architecture does not preclude it.

### macOS

SwiftUI and SwiftData work on macOS. The shared packages are platform-agnostic. Each app gets a macOS target in its Xcode project, with platform-specific UI adjustments (sidebar navigation, menu bar, keyboard shortcuts). The same App Group and Keychain sharing work on macOS. Subscription managed via shared Apple ID.

### Windows

Requires a separate codebase (likely C# with WinUI, or Kotlin). The local database is SQLite (same schema as SwiftData produces). The sync engine logic is reimplemented but follows the identical protocol — same Supabase endpoints, same conflict resolution rules, same field timestamps. The Supabase backend requires zero changes. Subscription requires a non-Apple payment provider (Stripe or similar).

### Browser

A web client (likely React or similar) connecting to the same Supabase backend. No local database needed — reads directly from Supabase with real-time subscriptions for live updates. The Supabase backend requires zero changes. Subscription via Stripe or similar.

### Android (if ever)

Kotlin with Jetpack Compose. Local database via Room (SQLite). Same sync protocol, same Supabase backend. Payment via Google Play Billing.

---

*This document should be updated as architectural decisions evolve during development. See the Changelog for a history of changes.*
