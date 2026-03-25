# Warm Productivity — CLAUDE.md

**This file is loaded automatically every session. Read it fully before writing any code.**

When you need depth on a specific task, load the relevant skill (listed below). When you need full context on a feature or data model, load the relevant document.

---

## What This Project Is

Three native iOS apps — Expense Tracker, Notes, To-Do — that share a single Supabase backend, a common data model, and a unified navigation shell. They are built and shipped independently but are designed to interoperate deeply.

- Full documentation index: Vision & Philosophy, System Architecture, Cross-App Integration Map
- App specs: Expense Tracker App Spec, Notes App Spec, To-Do App Spec (load the relevant one per session)

---

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Swift |
| UI Framework | SwiftUI |
| Architecture | MVVM |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions + Realtime) |
| Auth | Sign in with Apple via Supabase Auth |
| File Storage | Supabase Storage (receipt photos) |
| Sync | Delta sync — version-based, last-write-wins |
| Local Persistence | SwiftData (Apple's modern persistence layer, backed by SQLite) |

**Local persistence:** SwiftData (Apple's modern persistence layer, backed by SQLite). All three apps share a single SwiftData store using an iOS App Group (`group.com.warmproductivity.shared`). This gives instant cross-app data access without network round-trips — data written in one app is immediately readable in the others.

---

## Project Structure

```
warm-productivity/
├── Apps/
│   ├── ExpenseTracker/          ← Expense Tracker iOS app
│   │   ├── ExpenseTracker.xcodeproj
│   │   ├── Sources/
│   │   └── Resources/
│   ├── Notes/                   ← Notes iOS app
│   │   ├── Notes.xcodeproj
│   │   ├── Sources/
│   │   └── Resources/
│   └── ToDo/                    ← To-Do iOS app
│       ├── ToDo.xcodeproj
│       ├── Sources/
│       └── Resources/
├── Packages/
│   ├── SharedModels/            ← SwiftData entities, shared across all apps
│   ├── RecurrenceEngine/        ← Shared recurrence logic: pattern evaluation, next-date calculation, schedule anchoring. Built during Expense Tracker Phase 5, reused by To-Do Phase 3.
│   ├── SyncEngine/              ← Sync logic, conflict resolution, queue management
│   ├── SupabaseClient/          ← Supabase SDK configuration, auth, API helpers
│   ├── SharedUI/                ← Design system: colors, typography, spacing, shared components
│   └── SharedUtilities/         ← Common helpers, extensions, formatters
├── Supabase/
│   ├── migrations/              ← Numbered SQL migration files
│   ├── functions/               ← Edge Functions (complex writes, exchange rates)
│   └── seed.sql                 ← Initial data (default categories, onboarding content)
├── Docs/
│   ├── 01_Vision_and_Philosophy.md
│   ├── 02_System_Architecture.md
│   ├── 03_Cross_App_Integration_Map.md
│   ├── 04_Development_Roadmap.md
│   ├── 05_Expense_Tracker_App_Spec.md
│   ├── 06_Notes_App_Spec.md
│   ├── 07_Todo_App_Spec.md
│   └── 08_Changelog.md
├── Skills/                      ← Claude skills for AI-assisted development
└── CLAUDE.md                    ← Project-level AI instruction file
```

**Dependency direction is strictly one-way: apps depend on `Packages/`, `Packages/` never imports from apps.** Never break this.

**SharedUI package contents (defined before Phase 1 UI begins):**
- Color palette (primary, secondary, background, surface, error, success — light and dark variants)
- Typography scale (title, headline, body, caption — using SF Pro)
- Spacing system (4pt grid: 4, 8, 12, 16, 24, 32, 48)
- Corner radius tokens (small: 8, medium: 12, large: 16)
- Shared components: FABButton, TransactionRow, EmptyStateView, LoadingView, ErrorBanner, TokenAutocompleteField

**SharedUtilities package contents:**
- `CommandParser` — pure Swift struct. Takes a raw FAB/quick-add string and returns a typed `ParsedCommand` struct with all recognised tokens (title, amount, currency, category, account, person, hashtags, date). No UI, no SwiftData imports. Fully unit-testable. Used by Expense Tracker (FAB) and To-Do (quick-add).

**TokenAutocompleteField (SharedUI):** Reusable SwiftUI component for all token-based autocomplete across all three apps. As the user types a token prefix (@ category, $ account, / person, # hashtag), shows a real-time dropdown filtered by prefix match. Enter or tap confirms selection. Escape or tap-outside dismisses. If no matches exist, shows "Create '[typed text]'" option which triggers record creation. The component takes a token type and a data source closure — the caller provides the filtered results, the component handles display and selection.

No app may define its own colors, fonts, or spacing constants. All visual constants come from SharedUI.

**RecurrenceEngine package** (built during Expense Tracker Phase 5):
- Pattern evaluation: given a `todo_recurrence_rules` record, calculate the next due date from a reference date
- Supports all patterns: daily, weekly, specific_days, monthly (by date or position), yearly
- Supports both anchor modes: fixed schedule and after_completion
- Pure Swift, no UI, no SwiftData imports — takes a rule struct, returns a `Date`
- Consumed by: Expense Tracker (planned expense scheduling), To-Do (recurring task scheduling)

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| Types (structs, classes, enums, protocols) | PascalCase | `ExpenseTransaction`, `NoteEntry` |
| Properties and functions | camelCase | `amountCents`, `fetchTransactions()` |
| Views | PascalCase + `View` suffix | `TransactionListView` |
| ViewModels | PascalCase + `ViewModel` suffix | `TransactionListViewModel` |
| Repositories | PascalCase + `Repository` suffix | `TransactionRepository` |
| Files | Match the type name | `TransactionListView.swift` |
| Database columns | snake_case (PostgreSQL) | `amount_cents`, `deleted_at` |
| Swift ↔ DB mapping | `CodingKeys` enum per model | maps `amountCents` → `amount_cents` |

---

## Architecture Pattern

**MVVM + Repository pattern — enforced consistently**

Every screen follows this structure:
- `SomeView` — SwiftUI view, observes ViewModel, no business logic
- `SomeViewModel` — `@Observable` class, owns UI state, calls Repository
- `SomeRepository` — pure Swift class, reads/writes SwiftData, owns query logic

Views never talk to Repositories directly. Repositories never import SwiftUI. This is the only allowed pattern — no exceptions.

---

## Core Principles

**1. DRY — enforced by `Shared/`**
If logic or a UI component exists in two apps, it moves to `Shared/`. No exceptions. This includes models, repository methods, sync logic, and SwiftUI views.

**2. KISS — no speculative abstractions**
Solve the problem in front of you. Do not build base classes, generic wrappers, or abstraction layers for hypothetical future needs. A pattern earns abstraction when two concrete cases already exist.

**3. Modularity — one-way dependencies**
Apps depend on `Shared/`. `Shared/` has zero knowledge of individual apps. Cross-app UI is explicitly deferred until all three standalone apps are complete. Never wire app-to-app UI before then.

**4. Schema-First — the schema is the source of truth**
The full database schema is deployed before any UI is built. When there is tension between what the UI seems to need and what the schema defines, the schema wins. Change the schema deliberately, document the change, never work around it.

**5. Standalone First — cross-app UI last, AI last of all**
Each app is built as a fully functional standalone tool first. Data layer integration (writing to `note_entries`, `entity_links`, `activity_log`) happens from day one. Cross-app UI (slash commands, linked references, dashboards) is deferred until all three apps are complete. AI features come last.

**6. FIX NOW, NO FUTURE DEBT**
Every database rule — triggers, constraints, CHECK clauses, CASCADE behavior, UNIQUE enforcement — must be enforced in the Swift layer at the time the feature is built. Never defer constraint enforcement to "when sync is built" or "a future phase." If the schema defines it, the repository enforces it locally before the feature ships. The database is the source of truth; the Swift code is the local mirror.

**7. Offline-First Constraint Enforcement**
Because all writes go to SwiftData first (offline-first), the Swift repositories must replicate the behavior of every server-side trigger and constraint that affects data integrity. Specifically:
- **`update_version_and_timestamp()`** — every repository `update()` must increment `version` and set `updatedAt = Date()` before save.
- **`update_bank_account_balance()`** — `TransactionRepository` must adjust `ExpenseBankAccount.currentBalanceCents` on every create, update, soft-delete, and restore of a transaction.
- **`validate_transaction_hashtag_fk()`** — `TransactionHashtagRepository` must verify the referenced transaction exists in the correct table (ledger or inbox) before insert.
- **UNIQUE constraints** — repositories must check for duplicates before insert and reject them.
- **CASCADE deletes** — soft-deleting a parent must cascade `deletedAt` to all children.
- **SET NULL on delete** — soft-deleting a referenced entity must nullify the FK on dependents.
- **CHECK constraints** — enforce all CHECK clauses (e.g., `is_pinned = true` requires `notebookId != nil`).
- **Currency from account** — a transaction's currency is derived from its account's `currencyCode`. When an account is selected, `exchangeRate` must be auto-populated if account currency ≠ home currency.

---

## Schema Conventions

Every mutable table has:
```
created_at   (timestamptz, default now())
updated_at   (timestamptz, default now())
version      (integer, NOT NULL, default 1)      ← delta sync key
deleted_at   (timestamptz, nullable)             ← soft delete / tombstone
synced_at    (timestamptz, nullable)             ← last confirmed server sync
```

**Never hard-delete mutable rows.** Set `deleted_at`. Deletions propagate to other devices via delta sync.

**Delta sync query:** `WHERE version > last_seen_version AND user_id = ?`

**Conflict resolution:** last-write-wins by version number. Higher version wins the entire record.

**Exceptions** (no version/deleted_at required): reference tables (`exchange_rates`, `global_currencies`), externally managed tables (`users`), append-only tables (`activity_log`).

---

## Cross-App Data Patterns

**Universal Description Model** — no `description` column on any table. All free-text content lives in `note_entries`, linked via `entity_links`. This means Notes content appears in Notes automatically.

**entity_links** — the cross-app glue table. Every connection between an expense, task, or note goes through here. Always soft-delete entity_links (set `deleted_at`), never hard-delete.

**Tombstone pattern** — soft deletes everywhere. A deleted record stays in the database with `deleted_at` set. The sync engine picks it up and propagates the deletion to other devices.

---

## Decision Guidelines

When you encounter these decisions during development, resolve them using these criteria — then **document your decision in this file** under Emerging Conventions below.

**Navigation architecture**
- Linear flows → `NavigationStack`
- Master-detail (e.g., sidebar + content) → `NavigationSplitView`
- Tab-based app root → `TabView`
- Document choice and reasoning when first implemented

**What belongs in `Shared/`**
- A model, repository, or component moves to `Shared/` only when two or more apps need it
- Never move something speculatively — wait until the second use case exists
- Document what moved and why

**Error handling**
- Never lose user data silently. Writes always succeed locally first.
- Sync errors are surfaced non-destructively (no data loss, user is informed)
- Specific error UI patterns: document when first implemented

**Offline behaviour**
- All writes succeed locally immediately
- Sync resolves in the background when connectivity is restored
- Edge cases encountered: document the solution when first resolved

---

## Skills

Load these skills for specific task types. If a skill is listed but doesn't exist yet, create it first using the `skill-creator` skill before proceeding.

| Task | Skill to load | Status |
|---|---|---|
| Adding or modifying a database table or column | `database-schema` | ✅ Built |
| Creating a new SwiftUI component or screen | `component-creation` | ✅ Built |
| Scaffolding a new app target | `app-scaffolding` | ✅ Built |
| Writing or updating tests | `testing` | ⬜ Not built |
| Updating documentation after a code change | `documentation-sync` | ⬜ Not built |
| Implementing delta sync, version tracking, or conflict resolution | `sync-engine` | ⬜ Not built |
| Handling multi-currency amounts, exchange rates, or home currency conversion | `multi-currency` | ✅ Built |
| Creating or managing cross-app links, entity_links, or Universal Description Model | `entity-links` | ⬜ Not built |

**Build order:** Skills should be created in this sequence, as each one unlocks the next stage of development.

1. `database-schema` — needed first because the full schema is deployed before any UI is built (schema-first principle)
2. `multi-currency` — needed during Phase 1 of Expense Tracker (multi-currency is core, not optional)
3. `component-creation` — needed to build Phase 1 UI consistently across all three apps
4. `app-scaffolding` — needed when spinning up App #2 and App #3 targets
5. `testing` — needed once Phase 1 of App #1 is hardened and ready for test coverage
6. `documentation-sync` — needed throughout but most critical once the codebase starts diverging from the planning docs
7. `sync-engine` — needed once core data layer exists and sync must be implemented
8. `entity-links` — needed when wiring cross-app data layer (Universal Description Model, entity_links)

**When a skill is built**, update its status above from ⬜ Not built to ✅ Built.

**Skills live at:** `Skills/<skill-name>/SKILL.md`

---

## Update Protocol

**This file is a living document.** After any session that introduces something new, update the relevant section before closing.

- **New navigation decision made** → add to Emerging Conventions with choice and rationale
- **Something moved to `Shared/`** → add to Emerging Conventions with what moved and why
- **Schema change made** → confirm it's reflected in System Architecture doc, note the pattern here
- **Edge case resolved** → add to Emerging Conventions with the solution
- **Phase completed** → add a section under Emerging Conventions with new patterns that appeared
- **App completed** → add an App Lessons section capturing patterns invented, anti-patterns discovered, decisions that didn't survive contact with the code

---

## Emerging Conventions

*This section is written by the AI during development.*

### CodingKeys — Handled by SyncEngine, Not @Model Classes

CLAUDE.md's naming table says "CodingKeys enum per model." However, SwiftData `@Model` classes do **not** use `Codable` for local persistence — SwiftData has its own schema system. Adding `CodingKeys` to `@Model` classes has no effect on SwiftData and cannot enable `Codable` conformance without also writing manual `init(from:)` and `encode(to:)` (which conflicts with the `@Model` macro).

**Decision:** The camelCase ↔ snake_case mapping is the SyncEngine's responsibility. When the `sync-engine` skill is built, it will either:
- Use `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase` globally, or
- Create lightweight DTO structs in the SyncEngine package for API serialization

This keeps SharedModels as pure SwiftData models with no Codable concern.

### Navigation — TabView (iOS 26)

Deployment target is iOS 26.0. TabView uses automatic Liquid Glass tab bar. The iOS 18+ `SwiftUI.Tab` API is now available but not yet adopted — still using `.tabItem { Label(...) }` pattern.

### Color Extensions in `.foregroundStyle()`

`Color` extensions (e.g., `Color.wpTextSecondary`) do not auto-resolve as `ShapeStyle` members. Always write the full `Color.wpTextSecondary` form, never `.wpTextSecondary`, inside `.foregroundStyle()`.

### Liquid Glass Design Convention (iOS 26)

**Glass is for the navigation layer only.** Apply `.glassEffect()` to interactive navigation elements: sidebar cards, FAB, toolbar pills, search bar, autocomplete dropdowns. Never on content (list rows, transaction rows, tags, empty states, error banners).

**Rules:**
- `.glassEffect()` is always the LAST modifier in the chain
- Never nest glass in glass — use `GlassEffectContainer` if grouping multiple glass elements
- Root view containers use `.background(.background)` (system semantic) or `.background(.clear)` for sheets, NOT `Color.wpBackground` / `Color.wpGroupedBackground`
- Content areas that need a visible bounded surface keep `Color.wpSurface`
- Use `.scrollContentBackground(.hidden)` on List views so glass nav/tab bars show through
- Sheets at partial height get glass automatically — remove custom drag handles and solid backgrounds
- Primary CTA buttons (Promote, Get Started) keep solid `Color.wpPrimary` for contrast

### Amount Display Convention

**Color rule (universal — applies everywhere amounts are shown):**
- **Positive amounts** → `Color.wpIncome` (muted green, `#2d8a4e` light / `#4ade80` dark)
- **Negative amounts** → `Color.wpExpense` (standard text color, black/white — same as `wpTextPrimary`)
- No red for expenses. The sign (`-`) already communicates direction; red is reserved for `wpError` (validation, destructive states).
- This rule applies to transaction rows, detail views, search results, category breakdowns, sidebar balances — no exceptions.

**Currency format:** Always use the 3-letter ISO currency code (e.g. `USD`, `PEN`), never the locale symbol (`$`, `S/`). Many currencies share `$`; the code is unambiguous. Format: `-USD67.32`, `+PEN1,500.00`.

### Transaction Row Layout Convention

**Ledger rows:** Category color stripe (left) · Title · Account name · Signed amount
**Inbox rows:** Green stripe if ready to promote, nothing otherwise · Title · Account name (if available) · Signed amount

**Truncation rule:** The title is the only element that truncates (`...`). Account name and amount never truncate — they use `fixedSize()` to guarantee full display. This ensures the financial data is always readable.

**Row grouping:** Both ledger and inbox rows are wrapped in a `Color.wpSurface` card with `WPCornerRadius.medium` rounded corners. Dividers appear between rows (not after the last one).

### Transaction Detail / Quick Entry — Unified Sheet

**One component for both new (FAB +) and edit (tap existing).** The same bottom sheet UI handles creation and editing:

1. **Command input line** — free-text field with inline token highlighting (`@Category` in green, `$Account` in green). The command string is the canonical representation. When editing an existing transaction, the command string is reconstructed from stored fields.
2. **Description field** — always uses the Universal Description Model (`note_entries` + `entity_links`). Never a plain text column on the transaction.
3. **Chip bar** — shows parsed/assigned fields as pills:
   - **Filled pills** (solid border, colored text) = field has a value (e.g., "Today", "Dining", "Chase")
   - **Dashed/missing pills** (placeholder text) = field is empty, needs input (e.g., "Category", "Account")
4. **Promote/submit button** — active (filled `wpPrimary`) when all required fields are complete, disabled (grayed) when not.
5. **Overflow menu** (`...`) for extra actions.

**Data flow:** Command string → `CommandParser` parses → chips reflect parsed tokens. Same code path for new and edit.
