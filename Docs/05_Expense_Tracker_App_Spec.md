# Warm Productivity — Expense Tracker App Spec

**App #1 of 3 — Also builds the shared ecosystem infrastructure**

---

## Context Loading Guide

Load these documents and skills at the start of every Expense Tracker dev session:

| Load | Why |
|---|---|
| `CLAUDE.md` | Loaded automatically — hard rules, naming conventions, principles |
| `warm-productivity-system-architecture.md` | Full schema, sync model, cross-app data patterns |
| `warm-productivity-vision-and-philosophy.md` | Design philosophy, UX principles |
| `warm-productivity-cross-app-integration-map.md` | What this app writes to shared tables, what's deferred |
| This document | Screens, flows, phases, edge cases |

Load the relevant skill for the current task type (see CLAUDE.md Skills table).

---

## App Overview

The Expense Tracker is the financial core of the Warm Productivity ecosystem. It gives the user total visibility and control over their spending — across multiple currencies, multiple accounts, and shared expenses with other people.

It is built first because it is the most complex app and because building it also produces the shared infrastructure (auth, navigation shell, sync engine, shared package, deployment pipeline) that Apps #2 and #3 inherit.

**Core value proposition:** Log expenses fast via a command-line-style input, keep incomplete records in an inbox until they're ready, and let the ledger be a clean, reliable record of confirmed transactions.

---

## Build Phases

Each phase hardens completely before the next begins. "Hardened" means: locally tested, deployed to production, tested in real deployment, confirmed stable.

UI polish passes happen at natural milestones — after a group of phases delivers a usable feature set. The first polish pass comes after Phases 1–2, when core tracking and search are functional but before reconciliation adds complexity.

| Phase | Name | Scope |
|---|---|---|
| 1 | Core Tracking | Inbox/ledger, categories, hashtags, multi-currency, accounts, descriptions, CSV import |
| 2 | Search & Filtering | Category breakdown, hashtag filtering, search |
| — | **UI Polish Pass 1** | Visual refinement of all Phase 1–2 screens: spacing, alignment, transitions, empty states, loading states, error states, dark mode consistency, accessibility |
| — | **Sync Engine** | Build SyncEngine package, wire up delta sync for all Phase 1–2 entities. Every subsequent phase is built and tested with sync from day one |
| 3 | Reconciliation | Batch reconciliation, field locking + sync verification |
| 4 | People & Transfers | `/` syntax, person accounts, debt tracking, cross-user sharing + sync verification |
| 5 | Expense Planning + Recurrence | Planned expenses, recurring templates, overdue section, shared recurrence engine + sync verification |
| 6 | Polish & Utilities | Receipt photos, CSV export, final full-app polish pass |

**Deferred to Step 12 (Cross-App UI):** Budget tracking UI, dashboard.
**Deferred to Step 13 (AI Layer):** Voice entry, natural language parsing.

> **Note:** Future-date routing ships as part of Phase 5 (Expense Planning). The data model is defined in the Cross-App Integration Map; the feature UI is built here alongside Expense Planning.

---

## Architecture Notes

**Local storage:** All data is persisted locally using SwiftData. The three apps share a single SwiftData store via an iOS App Group, meaning data written in Expense Tracker is instantly accessible in Notes and To-Do without a network round-trip.

---

## Screens & Flows

### Authentication & Onboarding

**Launch Screen**
Standard iOS launch screen displayed while the app initializes and checks for an existing session.
- Returning users with a valid session → skip everything → land directly on Transactions tab
- New users or expired sessions → Sign In Screen

**Sign In Screen**
- App name and logo
- Sign in with Apple button
- On success: new users → Setup Screen. Returning users → Transactions tab

---

**Setup Screen** *(new users only, shown once)*

A single screen. No wizard, no steps. Two required inputs and a button.

```
[App logo]

Welcome to Warm Productivity

Main Currency
┌─────────────────────────────┐
│  USD  ▾                     │   ← picker over global_currencies, searchable
└─────────────────────────────┘

First Bank Account
┌─────────────────────────────┐
│  e.g. Chase, BCP PEN...     │   ← free text, becomes the account name
└─────────────────────────────┘

        [ Get Started ]            ← disabled until both fields filled
```

On "Get Started":
1. Creates `user_settings` row with the chosen `main_currency`
2. Creates the first `expense_bank_accounts` row with the entered name and currency matching `main_currency`
3. Creates 2 demo ledger transactions (see below)
4. Navigates to the Transactions tab

---

**Demo Transactions** *(created on first launch, deleted by the user)*

Two real-looking ledger transactions seeded into the new user's account immediately after setup. They use the bank account and currency created in Setup. They use the system category `@Other` (no user categories are pre-created). They look identical to any real transaction — no badge, no label, no special marker.

The only signal that they are demo content is their description text, which ends with a bold call to action.

**Demo Transaction 1 — Expense:**
- Title: `Morning Coffee`
- Amount: `-12.00` (in the user's chosen currency)
- Account: the account created in Setup
- Category: `@Other`
- Date: today
- Description: *"Welcome! This is a demo transaction. Tap the FAB (+) at the bottom to add your first real expense — try typing '-45 Lunch @Food' for a quick entry. Tap any row in the sidebar (a bank account, category, or person) to filter your transactions. **Delete this transaction when you're ready to get started.**"*

**Demo Transaction 2 — Income:**
- Title: `Monthly Salary`
- Amount: `+3,000.00` (in the user's chosen currency)
- Account: the account created in Setup
- Category: `@Other`
- Date: today
- Description: *"This is your second demo transaction. Swipe left on any transaction row to delete it. Each transaction has an attached description — this is it. You can add your own notes to any transaction using the description field. **Delete this transaction when you're ready to get started.**"*

The user must delete both transactions individually by swiping left. There is no "Clear demo data" option. Once both are deleted, the true empty state appears: "Nothing to see here! Add a transaction."

**Implementation note:** Demo transactions are standard `expense_transactions` records with `source_text = 'onboarding'`. No special schema field is needed — they behave identically to user-created transactions in every way.

---

### Main Navigation

Bottom tab bar with 4 tabs: **Transactions · Budgeting · Reconciliations · Settings**

Both the tab bar visibility and the contents of each sidebar are configurable per user (Phase 1). Users can hide tabs they don't use and hide sidebar sections they don't need.

**Tab visibility is phase-progressive.** Phase 1 ships with 2 tabs: Transactions and Settings. The Budgeting tab is added in Phase 2 when budget features are built. The Reconciliations tab is added in Phase 3 when bank reconciliation is built. The 4-tab structure shown here is the target state after all phases are complete.

---

### Transactions Tab

**Transactions Menu (root screen of Transactions tab)**

Sidebar-style navigation menu. This is the hub — tapping any item navigates into a filtered transaction list.

The sidebar is a flat list divided into five sections. Inbox and Ledger are always visible pinned items at the top. Bank Accounts, People, and Categories are collapsable sections below, each showing their items inline with their balance or spend amount on the right. There is no Reconciliation section in the sidebar — reconciliation lives only in its own tab.

Visual format of each row: `Name` on the left, `±SymbolAmount` on the right. Example:

```
Inbox
Ledger

Bank Accounts
  BCP PEN              S/1,029
  BCP USD              $292

People
  Alex                 -S/1,000
  Alex                  +$120
  Daniela              -$929

Categories
  Food                 -S/100
  House                -S/200
```

| Section | Collapsable | Amount shown | Source | Tapping |
|---|---|---|---|---|
| Inbox | No — always visible | — | — | Inbox List |
| Ledger | No — always visible | — | — | Ledger List |
| Bank Accounts | Yes | All-time running balance in home currency | `amount_home_cents` totals — all transactions converted to the user's main currency for a coherent single number per account | Filtered list by account |
| People | Yes | All-time debt balance in original account currency | Sum of transactions on that virtual account (expressed in the account's native currency, not converted) | Filtered list by person |
| Categories | Yes | Current calendar month spend in home currency | Calculated as `SUM(amount_home_cents)` for transactions in that category within the current calendar month. Displayed in the user's `main_currency`. This ensures a coherent total even when the user has accounts in multiple currencies. | Filtered list by category |

**People rows are per virtual account, not per person.** Because each person has one virtual account per currency (e.g., Alex PEN and Alex USD are separate accounts), the same person can appear multiple times — once per currency they share expenses in. The currency is implicit from the account's `currency_code`, shown via the amount symbol.

**People section** shows amounts in the original account currency (NOT converted to home currency) — because debt with a specific person is always meaningful in the currency it was incurred. A -S/1,000 debt with Eliana should show as S/1,000 PEN, not converted to USD.

**Amount sign convention:**
- Bank Accounts: positive = you have money in this account (expressed in home currency)
- People: negative = you owe them, positive = they owe you (expressed in the account's native currency, not converted)
- Categories: negative = money spent (outflow), positive = income received (expressed in home currency)

---

**Zero-balance rows:** Rows in each sidebar section are hidden when their balance is exactly zero. A bank account with $0 is not shown; a category with no spend this month is not shown; a person whose debt is fully settled is not shown. The section header itself remains visible as long as at least one row is non-zero.

**Sidebar empty state:** When a section has no rows at all (not zero-balance rows — literally no records exist yet), show the section header followed by a small grey helper text:
- Bank Accounts section: "Add your first bank account"
- People section: "Add your first person"
- Categories section: "Add your first category"

Tapping the helper text opens the relevant creation flow (same as long-pressing the FAB or going to Settings).

---

**Row Interaction Model**

| Row type | Single tap | Long-press | Swipe left |
|---|---|---|---|
| Inbox header | Full inbox list | — | — |
| Transactions header | Full ledger list | — | — |
| Individual transaction row (any list) | Opens Transaction Detail Modal | — | Delete (soft) |
| Bank account row | Filtered transaction list for that account | Context menu | — |
| Person row | Filtered transaction list for that person | Context menu | — |
| Category row | Filtered transaction list for that category | Context menu | — |
| Hashtag row | Filtered transaction list for that hashtag | Context menu | — |
| Section header (Bank Accounts, People, etc.) | — | — | — |
| Section "Edit" button | Enters drag-to-reorder mode | — | — |

**Context menu (long-press on any sidebar row):** Rename · Change Color · Delete. Bank accounts use "Archive" instead of "Delete" — an account with historical transactions cannot be hard-deleted; archiving hides it from new transaction pickers while preserving history. System categories (@Debt, @Other) show no Delete option.

**Drag-to-reorder:** Tapping the "Edit" button on a section header puts that section into edit mode. Each row shows a drag handle (≡) on the right. Drag rows to reorder. Tap "Done" to exit. Order is persisted to `sort_order` and synced across devices.

**Section header `+` button:** Every section header in the Transactions tab (Bank Accounts, People, Categories, Hashtags) has a `+` button on the right side of the header row. Tapping it opens a creation sheet for that type: new bank account, new person (Phase 4), new category, new hashtag. This is the primary creation path for sidebar items. The FAB long-press is a secondary path. The `+` pattern is used consistently across all three apps wherever a section can receive new items.


**Inbox List**

Incomplete transactions waiting to be promoted to the ledger.

Layout:
- **Search bar** — filters inbox items by title in real time
- **Overdue section** (collapsable, shows count) — inbox items whose `date` is in the past
- Remaining items grouped by date
- Each row: title (or "UNTITLED"), amount (if set), date (if set, red if overdue), category (if set), visual indicator for missing required fields
- Sorted per user's `transaction_sort_preference` (date or created_at)
- **Swipe to delete** — soft deletes the record (sets `deleted_at`)

**Promotion trigger:** Promotion is user-initiated, not automatic. When all mandatory fields are filled (title, amount, date, bank account, category) and the date is today or past, the inbox item shows a **ready indicator** (small green dot or checkmark badge on the row) and a small **Promote button** becomes available. The user taps Promote to move the expense to the ledger. This lets users add optional fields (hashtags, description, receipt photo) before promoting. If any mandatory field is missing, the Promote button is hidden and the row shows a visual indicator for missing fields instead. Once promoted, further edits are made via the Ledger transaction detail view.

**Recurring templates never appear in the Inbox.** Records with `is_recurring = true` have `date = null` permanently. Since promotion requires `date IS NOT NULL AND date <= today`, recurring templates can never become ready for promotion. They are visible only in the Expense Planning section (Phase 5) and are not shown in the Inbox list.

---

**Ledger List**

Confirmed transactions — the clean, reliable record.

Layout:
- Transactions grouped by date
- Each row: title, amount (formatted in account currency, with home currency equivalent if different), date, category, account
- Sorted per user's `transaction_sort_preference`
- **Swipe to delete** — soft deletes the record

**Transaction list empty state:** When the inbox and ledger are both empty (first launch or after deleting everything), the transaction panel shows centred text: "Nothing to see here! Add a transaction." with a subtle arrow or visual cue pointing to the FAB.

---

**Filtered Transaction List**

Same layout as the Ledger List, filtered by the tapped item (account, person, or category). Navigation: back arrow (top left) → Transactions Menu.

---

**Transaction Detail Modal**

Half-screen bottom sheet. Slides up from the bottom when any transaction row is tapped in any list. Same component for both inbox and ledger transactions — conditional sections handle the differences.

**Fields (all transactions):**
- Title — editable text field
- Date — editable date picker; accepts "Today", "Tomorrow", "Yesterday" shortcuts
- Amount — editable, with +/− sign toggle
- Currency — read-only label derived from the bank account's currency
- Bank Account — editable picker
- Category — editable picker with `TokenAutocompleteField`
- Hashtags — editable multi-select with `TokenAutocompleteField`
- Exchange rate — shown only when account currency ≠ user's `main_currency`. Auto-populated from the global `exchange_rates` reference table for the transaction date (falls back to most recent available rate for that currency pair). User can override. Never blocks promotion.
- Description — editable text area. Writes to `note_entries` via Universal Description Model
- Receipt photo — shown as an attachment thumbnail row if a photo exists (Phase 6). Tapping opens the photo full-screen. If no photo, row is hidden (Phase 6 adds the "Attach photo" option)

**Inbox-only behaviour:**
Required fields for ledger promotion: **title, amount, date, bank account, category**. Exchange rate is never a required field — it auto-populates from the global `exchange_rates` table for the transaction date and is always available as a fallback. The user can override it manually but it will never block promotion.

- Missing required fields are highlighted with a subtle red indicator on each empty row
- A small **Promote** button (top-right of modal) is visible only when all required fields are filled AND date ≤ today. Tapping it promotes to ledger atomically and the modal closes. When any required field is missing, the Promote button is hidden and missing fields are highlighted with a subtle red indicator
- No reconciliation row shown (inbox transactions cannot be reconciled)

**Ledger-only behaviour:**
- **Reconciliation row** — shown below hashtags. If the transaction belongs to a completed reconciliation: "Reconciled · [Batch Name]" — tapping navigates to that reconciliation detail. If not reconciled: "Not reconciled" (read-only label, no action)
- If the transaction is part of a completed reconciliation batch: `title`, `amount`, `date`, and `account` fields are read-only, each showing a 🔒 icon. All other fields remain editable
- No Confirm button

**Delete:**
- A "Delete Transaction" button at the bottom of the modal, styled destructively (red text)
- Tapping shows a confirmation alert. On confirm: soft-deletes the record (`deleted_at` set), modal closes, row disappears from list
- If the transaction belongs to a completed reconciliation, the delete alert adds a warning: "This transaction is part of a reconciliation. Deleting it will affect that reconciliation's totals."
- If the transaction is assigned to a **draft** reconciliation (not yet completed), it is silently removed from the draft on deletion — no warning shown. The draft's balance summary updates automatically.

---

---

**Search**

Tapping the search bar at the top of the Transactions tab root screen navigates to a dedicated full-screen Search view (not an inline filter).

Layout:
- Search bar pinned at the top (auto-focused, keyboard appears immediately)
- Results list below — empty when the search field is empty
- Results update with every keystroke
- Back button (top-left) exits search and returns to the Transactions tab root

Search covers both inbox and ledger transactions.

Search scope: title, category name, hashtag name, bank account name, person name, description text (`note_entries` content linked via `entity_links`), amount (exact and partial match)

Each result row uses the same layout as a transaction row in the Ledger List. Tapping a result opens the Transaction Detail Modal.

---

**Inline Management (Bank Accounts, Categories, Hashtags)**

Bank accounts, categories, and hashtags are created and managed directly from the Transactions tab — not from Settings.

**Creating:** Every section header has a `+` button (right side of the header row) — tapping it opens a creation sheet for that type. Bank accounts, categories, and hashtags can also be created inline via the FAB command line: unrecognised `@Name` auto-creates a category, `#name` auto-creates a hashtag. The "Create '[typed text]'" option in the `TokenAutocompleteField` dropdown does the same. Bank accounts cannot be auto-created from the command line — use the `+` button or FAB long-press.

**Editing and deleting:** Long-press on any bank account, category, or hashtag row in the Transactions tab → context menu: Rename · Change Color · Delete (or Archive for bank accounts).

**Reordering:** Tap the "Edit" button on a section header → rows show drag handles (≡) → drag to reorder → tap "Done". Order is saved to `sort_order` and synced.

---

### FAB — Quick Entry (all tabs except Settings)

A floating action button visible on all tabs except Settings. Always available — the user should always be ready to add an expense, regardless of which tab they are on. Tapping it expands a quick entry panel from the bottom of the screen without covering the full view.

**Panel layout:**
1. **Command line** — single text input for typed commands (see Command Syntax below)
2. **Description field** — note/description input (writes to `note_entries` via Universal Description Model)
3. **Toolbar** — individual field buttons:

| Button | Action |
|---|---|
| 📅 Date | Date picker. Also accepts: `Today`, `Tomorrow`, `Yesterday` typed in command line |
| @ Category | Category picker |
| $ Account | Account picker |
| \# Hashtag | Hashtag multi-select |
| / Paired | Paired transaction target picker (Phase 4) |
| ··· More | Exchange rate override |

**Command Syntax:**

`[amount] [title] [@category] [$account] [#hashtag] [date]`

| Symbol | Meaning | Example |
|---|---|---|
| `-` / `+` prefix | Expense / income sign | `-60`, `+200` |
| Plain text | Transaction title | `Lunch`, `Salary` |
| `@Name` | Category | `@Food`, `@Salary` |
| `$Name` | Bank account | `$BCP_PEN`, `$Chase_USD` |
| `#name` | Hashtag | `#groceries` |
| `/Name +amount` | Paired transaction target (Phase 4) | `/Eliana +30` |
| `Today` / `Tomorrow` / `Yesterday` | Date shortcuts | `Yesterday` |

**`/Name` autocomplete:** As the user types `/El`, a small inline suggestion list appears showing all matching virtual accounts with their currency label: e.g., `Eliana PEN`, `Eliana USD`, `Elena HKD`. The user taps to select one. This disambiguates person accounts that share a name across currencies. The suggestion list only shows accounts with `is_person = true`. Unrecognised `/Name` tokens (no match found) create a new person virtual account for the transaction's primary account currency.

**Token autocomplete:** As the user types any token (@ for category, $ for bank account, / for person, # for hashtag), a real-time dropdown appears showing all matching records, filtered by prefix. Typing "@F" shows "Food", "Folding", "Foul", "Fast". Typing "@Fo" shows "Food", "Folding", "Foul". Typing "@Foo" shows only "Food". Enter or tapping a row confirms the selection. The dropdown dismisses on Escape or tapping outside. If no matches exist, the dropdown shows "Create '[typed text]'" as the only option — tapping it creates the record. This component (`TokenAutocompleteField`) is shared across all three apps via SharedUI.

**Parsing rules:**
- **Order-independent:** Tokens can appear in any order. `-60 Lunch @Food $BCP_PEN` is identical to `@Food $BCP_PEN -60 Lunch`. The parser identifies each token by its prefix symbol, not its position.
- **Duplicate tokens:** If the same token type appears twice (e.g., `@Food @House`), the last occurrence wins.
- **Unknown words:** Any word or phrase that doesn't match a token pattern (no `-/+`, `@`, `$`, `#`, `/` prefix and not a date keyword) is treated as part of the title. Multiple plain-text segments are joined with a space.
- **Unrecognised tokens:** A `/Name` with no matching account creates a new person virtual account in the primary transaction's currency. An `@Name` with no matching category creates a new category. A `$Name` with no matching account shows an inline error — bank accounts cannot be auto-created.
- **Partial input:** Any combination of fields creates an inbox record. Only title, amount, date, account, and category are required for ledger promotion.

**Examples:**
- `-60 Lunch @Food $BCP_PEN` → creates inbox or ledger record depending on completeness
- `-90 Dinner @Food $BCP_PEN /Eliana +30 /Carlos +20` → primary + two paired transactions (Phase 4)
- `+3000 Salary @Income $BCP_PEN Today` → direct to ledger if all fields present

The raw command text is stored in `source_text` on the transaction record.

---

### Budgeting Tab

#### Navigation Structure

```
Budgeting Tab
└── Main View (3-month table, scrollable)
    ├── [← / →] 3-month window navigator
    ├── [Tap budget amount on current month column] → Inline edit
    └── [Tap category row] → Filtered transaction list for that category (current month)
```

---

#### Screen 1 — Main View (3-Month Table)

**What it is:** The default view when the user taps the Budgeting tab. Shows a table of expenses by category per month, displaying a rolling 3-month window. The rightmost column is always the current month. The user can scroll backward to see older months.

**Layout:**

```
┌──────────────────────────────────────────────────────────┐
│  Budgeting                                               │
├──────────────────────────────────────────────────────────┤
│  [←]    Jan 2026  ·  Feb 2026  ·  Mar 2026    [→]       │  ← 3-month window. [→] disabled when current month is rightmost
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Total          S/ 1,980   S/ 2,050   S/ 1,340    │  │
│  │  Budget         S/ 2,100   S/ 2,100   S/ 2,100    │  │
│  │  Remaining      S/ 120     S/ 50      S/ 760      │  │  ← green if within, red if over
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  Category       Jan 2026   Feb 2026   Mar 2026          │
│  ─────────────────────────────────────────────────────  │
│  Food           S/ 450     S/ 480     S/ 320            │
│                 / S/ 500   / S/ 500   / S/ 500          │  ← budget below spend
│  ─────────────────────────────────────────────────────  │
│  Transport      S/ 180     S/ 210     S/ 190            │
│                 / S/ 200   / S/ 200   / S/ 200          │
│  ─────────────────────────────────────────────────────  │
│  Housing    ⚠   S/ 520     S/ 490     S/ 620            │  ← ⚠ if current month over budget
│                 / S/ 500   / S/ 500   / S/ 500          │
│  ─────────────────────────────────────────────────────  │
│  Entertainment  S/ 120     S/ 80      S/ 0              │
│                 / S/ 150   / S/ 150   / S/ 150          │
│  ─────────────────────────────────────────────────────  │
│  @Debt          S/ 0       S/ 0       S/ 0              │  ← excluded from totals
│                 / S/ 0     / S/ 0     / S/ 0            │
│  ─────────────────────────────────────────────────────  │
└──────────────────────────────────────────────────────────┘
```

**Table details:**

- Categories as rows, months as columns — 3 months visible at a time
- Each cell shows: actual spend (top) and budget amount (bottom, prefixed with `/`)
- Ordered by current month's spend percentage descending — most at-risk categories surface to the top
- @Debt category is always shown last and excluded from the summary totals (budget = 0 by default, can be changed)
- Tapping a category row navigates to a filtered transaction list showing transactions for that category within the current month
- Cells where spend exceeds budget are highlighted in red
- The 3-month window slides with [← →] arrows. [→] is disabled when the current month is the rightmost column. [←] goes as far back as budget data exists

**Summary card:**
- Shows total spend vs total budget for each of the 3 visible months
- "S/ 760 remaining" in green when current month is within budget
- "S/ 120 over budget" in red if current month total is overspent

**Progress bar on current month:** The current month column (rightmost) includes a small progress bar below each cell, using the same colour logic:

| State | Threshold | Bar colour | Amount colour | Extra |
|---|---|---|---|---|
| Safe | 0-79% | Primary brand colour | Default | -- |
| Warning | 80-99% | Amber | Default | -- |
| Over budget | 100%+ | Red, full bar | Red | Warning icon next to category name + "S/ X over budget" line |

Past month columns show final numbers only — no progress bars (they're always 100% final).

---

#### Screen 2 — Inline Budget Edit (Current Month Only)

**Triggered by:** Tapping the budget amount in the current month column on any category row.

**What it is:** The budget amount in that cell becomes an editable text field in place. No modal, no sheet — the edit happens inline within the table.

**Behaviour:**
- Tapping the budget figure opens the numeric keyboard and highlights the current value
- The progress bar and summary card update live as the user types a new number
- Confirming: tap the checkmark button next to the field, or tap the Return key on the keyboard
- Cancelling: tap anywhere outside the cell
- The new budget amount is saved immediately on confirm
- Past month columns: budget amounts are displayed as plain text (not tappable). A small lock icon sits next to the amount to communicate it is read-only

---

#### Screen 3 — Budget Setup (First Enable)

**Triggered by:** The user turning on "Budget Mode" in Settings for the first time.

**What it is:** Not a wizard or modal flow. When the toggle is enabled in Settings, the Budgeting tab appears in the tab bar and the user is navigated there automatically. The tab opens showing the 3-month table with all categories showing S/ 0 (or blank) budget amounts and a persistent banner at the top prompting them to set their budgets.

**Behaviour:**
- The banner dismisses automatically once all categories have a budget amount set (including @Debt which can stay at 0)
- The user sets budgets by tapping each "[Set budget]" placeholder in the current month column — same inline edit interaction as Screen 2
- The user can also ignore some categories and come back later — the banner stays visible until all are set
- Setting a budget to 0 is valid (user explicitly does not budget for that category)
- @Debt pre-fills at 0 and does not show the "[Set budget]" placeholder — it shows "S/ 0" directly as its default is intentional

---

#### Screen 4 — New Category Prompt (Budget Mode Active)

**Triggered by:** User creates a new category while budget mode is enabled.

**What it is:** Immediately after the new category is created, a small bottom sheet slides up prompting the user to set a budget for it. This enforces the rule that all categories must have a budget when budget mode is on.

**Layout:**

```
┌──────────────────────────────────────────┐
│  —                                       │
│  Set a budget for #Dining           [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  How much do you want to budget          │
│  for #Dining each month?                 │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │  S/                                │  │
│  └────────────────────────────────────┘  │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │           Set Budget               │  │  ← primary button
│  └────────────────────────────────────┘  │
│                                          │
│           Set to 0 for now              │  ← secondary text link, skips with 0
│                                          │
└──────────────────────────────────────────┘
```

**Behaviour:**
- Tapping [✕] or "Set to 0 for now" sets the budget to S/ 0 and closes the sheet
- The category appears in the Budgeting tab with S/ 0 budget immediately
- If the user closes the sheet without setting (tapping ✕), the banner prompt from Screen 3 reappears in the Budgeting tab until the budget is set

---

#### States Summary

| State | 3-month nav | Inline editing | Budget amounts | Lock icon |
|---|---|---|---|---|
| Current month column | [← →] | Tap to edit | Editable | — |
| Past month columns | [← →] | — | Read-only | Lock icon |
| First enable | [← →] | Tap to edit (current month) | Blank / "Set budget" | — |

---

#### Edge Cases

1. **New month starts:** Budget locking is enforced client-side by date comparison — a month is considered locked once its last day has passed relative to the user's `display_timezone`. No database lock column is needed. When the app opens or comes to foreground, it checks the current date; past month columns render as read-only. The current month column resets all spend to S/ 0 but carries the same budget amounts forward. The 3-month window shifts so the new current month is the rightmost column.

2. **Changing a budget amount mid-month:** Fully allowed. The progress bar and table recalculate immediately against the new amount. No retroactive changes to previous months.

3. **Disabling budget mode:** Toggled off in Settings. The Budgeting tab disappears from the tab bar. All historical budget data is preserved — if the user re-enables later, all past months are still visible in the table.

4. **Category with no transactions this month:** Shows S/ 0 / S/ 500 in the current month column with an empty progress bar. Not hidden — the user should see they haven't spent in that category.

5. **Category deleted while budget mode active:** Budget row is soft-deleted alongside the category. Historical months that referenced that category still show the category name and amounts correctly (read-only). The deleted category no longer appears in the current month column.

6. **@Other category:** Shown in the table with a budget if set. Works identically to user-created categories. Not excluded from totals.

7. **How far back can the user scroll?** As far back as budget data exists. If there is no budget data for a given month (before budget mode was enabled), show an empty state: "No budget data for January 2026. Budget mode was enabled in February 2026."

8. **Category type changes while budget mode active:** Categories have `category_type` ('income' or 'expense'). Budgets apply only to expense-type categories. If a category's type is changed from 'expense' to 'income' while budget mode is active, its budget row is soft-deleted and the category moves to the income section of the dashboard. If changed back to 'expense', the user is prompted to set a new budget (same flow as Screen 4 — new category prompt). Historical months retain original budget data for the category under its type at the time.

9. **Re-enabling budget mode:** When the user disables and later re-enables budget mode, all historical budget data is preserved. The current month carries forward the most recent budget amounts. If new categories were created while budget mode was off, the Screen 3 setup prompt reappears for those categories only.

10. **Main currency changes while budget mode active:** Budget amounts are stored in `amount_cents` without a currency column — they are denominated in the user's `main_currency` at the time of entry. If `main_currency` changes, existing budget amounts are NOT automatically converted. The user must manually update budget amounts to reflect the new currency. A one-time banner warns: "Your home currency changed. Review your budget amounts."

---

### Reconciliations Tab

A reconciliation is a formal verification that the app's records match a bank statement for a specific account and period. The workflow: create a batch → assign transactions from within the reconciliation → compare running total against statement ending balance → close when the difference is zero.

**Navigation structure:**
```
Reconciliations Tab
└── Main List
    ├── [+] → Create Reconciliation Sheet → Reconciliation Detail (Draft)
    │                                            ├── [Add Transactions] → Transaction Picker Sheet
    │                                            └── [Close] → Reconciliation Detail (Completed)
    └── [Tap row] → Reconciliation Detail (Draft or Completed)
```

---

#### Main List

All reconciliations across all accounts, ordered by creation date (newest first). Account filter pills at the top (All · BCP PEN · BCP USD · ...). Each card shows: account name, status badge, date range, starting balance → ending balance, and difference. DRAFT badge is orange; RECONCILED badge is green. Difference shows green with a checkmark when $0.00, red when non-zero.

**Empty state:** "No reconciliations yet. Tap + to start your first one."

---

#### Create Reconciliation Sheet

Bottom sheet. Fields:

- **Bank Account** — dropdown of existing accounts
- **Period** — start date and end date pickers. Default: first and last day of the previous month. Reference only — no logic filters by this range
- **Starting Balance** — auto-filled from the ending balance of the most recently completed reconciliation for that account, determined by `end_date` (the one with the latest end date wins; draft reconciliations are ignored). If no completed reconciliation exists for that account, field is empty and the user must enter manually. Helper text shows "From previous reconciliation (Mar 2026)" or "First reconciliation for this account"
- **Statement Ending Balance** — always manual. The closing balance from the user's physical or digital bank statement

"Create Reconciliation" button is disabled until all four fields are filled. On create, sheet closes and user lands directly on the new Draft detail screen.

---

#### Reconciliation Detail — Draft

The main working screen. Balance summary card at the top, transaction list below.

**Balance summary card:**

| Row | Value |
|---|---|
| Starting Balance | Fixed at creation |
| + Movements | Sum of positive assigned transactions |
| − Movements | Sum of negative assigned transactions |
| Current Balance | Starting Balance + all movements (auto-calculated) |
| Statement Balance | Fixed at creation |
| **Difference** | Statement Balance − Current Balance (auto-calculated) |

Difference is red when non-zero. When it reaches exactly $0.00 it turns green with a checkmark.

**Transaction list:** All transactions assigned to this reconciliation, ordered by date ascending. Each row shows date, title, amount (green for positive, red for negative). Swipe left on a row to reveal "Remove" — this returns the transaction to unreconciled status without deleting it.

**"Add Transactions" button:** Always visible. Opens the Transaction Picker sheet.

**"Close Reconciliation" button:** Pinned to the bottom. Greyed out with label "Close Reconciliation — S/ 47.50 remaining" when difference ≠ 0. Active with primary colour when difference = 0. On tap, confirmation alert: "This will lock all transactions in this reconciliation. They cannot be edited after closing." On confirm → transitions to Completed state and locks `title`, `amount`, `date`, `account` on all included transactions.

**⋯ menu (top right):** "Edit Period & Balances" — opens a sheet allowing edits to all three creation-time fields: date range (start and end date), starting balance, and statement ending balance. All are editable while the reconciliation is in Draft state. The balance summary recalculates immediately on save. Not available on completed reconciliations. "Delete Reconciliation" (destructive, with confirmation; returns all transactions to unreconciled).

---

#### Transaction Picker Sheet

Slides up from "Add Transactions". Shows all unreconciled transactions for that bank account — transactions not yet assigned to any reconciliation. Only shows transactions that are: (a) from this bank account, (b) not already assigned to any reconciliation, (c) not soft-deleted, (d) in the ledger (inbox transactions cannot be reconciled). Sorted by date ascending (oldest first, matching the mental model of working through a statement).

Each row: date, title, amount, checkbox. Tapping anywhere on the row toggles selection. Search bar filters by title in real time. "Select All" selects all currently visible rows.

Footer updates live: "2 selected · Impact on difference: +S/ 200.00 → Remaining: S/ 152.50". This gives the user immediate feedback on how close they are to $0. "Add X Transactions" button is disabled when nothing is selected.

**Empty state:** "No unreconciled transactions for BCP PEN. All transactions may already be assigned to another reconciliation."

On confirm, sheet closes and transactions appear in the Draft detail list with the balance summary updated.

---

#### Reconciliation Detail — Completed

Read-only version of the Draft screen.

**Completed reconciliations are fully immutable.** No fields can be edited — not the date range, not the balances, not the transaction assignments. The only available action is Un-reconcile, which reverts the entire batch to Draft state.

Key differences:

- Status badge is green "RECONCILED" with a subtitle showing the close date ("Closed Mar 31, 2026")
- "Closing Balance" label replaces "Current Balance" (same value)
- No "Add Transactions" button
- No swipe-to-remove on transaction rows
- No "Close Reconciliation" button
- ⋯ menu has one option: "Un-reconcile"

**Un-reconcile flow:** Confirmation alert — "This will unlock all 18 transactions and return this reconciliation to Draft. The starting and ending balances will be preserved." On confirm: status reverts to Draft, all transactions become unreconciled and editable again.

---

#### States Summary

| | Draft | Completed |
|---|---|---|
| Badge colour | Orange | Green |
| Add transactions | ✅ | — |
| Remove transactions | ✅ swipe | — |
| Close button | ✅ (greyed if diff ≠ 0) | — |
| Edit balances | ✅ via ⋯ | — |
| Un-reconcile | — | ✅ via ⋯ |
| Transaction fields locked | — | title, amount, date, account |

---

#### Edge Cases

- **Multiple draft reconciliations for the same account** — allowed. A transaction can only be in one reconciliation at a time; it won't appear in another account's picker if already assigned
- **Date range is reference only** — transactions from outside the period can still be added; the UI does not warn or block
- **Currency** — all amounts in the account's native currency; no cross-currency reconciliation
- **Deleting a reconciliation** — all included transactions return to unreconciled status; no transactions are deleted

---

### Settings Tab

Standard grouped list. Changes apply immediately — no save button.

**Note:** Bank account, category, and hashtag management is handled inline from the Transactions tab via long-press or swipe actions, not from Settings.

---

**Profile** *(top of screen)*
- Initials avatar (first + last initial), display name (editable — opens a name edit sheet), email (read-only from Apple ID)
- Sign Out — confirmation alert before clearing session. Local data is not deleted; delta sync reconciles on next sign-in

---

**General**
- Appearance — Light / Dark / System. Updates `user_settings.theme`. System (default) follows the device setting.
- Main currency — picker over `global_currencies`. Changing updates `user_settings.main_currency`; existing transactions are not recalculated
- Display timezone — IANA timezone picker, grouped by region, searchable. Defaults to device timezone on first launch. All "today" calculations use this value
- Start of week — Sunday / Monday
- Transaction sort — Date (transaction date) / Created At (entry date)

---

**Display**
- Show Budgeting Tab — toggle. Updates `user_settings.expense_tab_show_budgeting`. Only appears in Settings after Phase 2 ships; absent before that
- Show Reconciliations Tab — toggle. Updates `user_settings.expense_tab_show_reconciliations`. Only appears after Phase 3 ships
- Sidebar Layout — navigation row → sub-screen. Phase 1: two rows — Bank Accounts and Categories with drag handles (≡) to reorder and visibility toggles. Phase 4 adds the People row when person virtual accounts are introduced. Inbox and Transactions rows are always visible in the Transactions tab and do not appear here (not configurable). Order here sets the order they appear in the Transactions tab.

---

**Notes Integration**
- Show linked notes in Notes app — toggle for `linked_notes_visible_in_notes_app`. Affects new linked notes only, never retroactive

---

**Budget**
- Budget mode — toggle for `budget_enabled`. Turning on navigates to the Budgeting tab with the first-enable setup prompt. Turning off shows a confirmation alert; all historical data is preserved

---

**Data**
- Import CSV — navigates to the CSV import flow (spec: CSV Import section)
- Export CSV — visible but greyed out with "Coming soon" label until Phase 6 ships

---

**Subscription**
- Plan — read-only row showing current state: "Free Trial · 14 days left", "Pro · Active", "Pro · Payment issue", "Pro · Ends Mar 31", "Free", etc.
- Manage Subscription — opens iOS system subscription management via StoreKit. The app never handles payment details

---

**About**
- Version — read-only (e.g., 1.0.0)
- Privacy Policy — external link
- Terms of Service — external link
- Contact Support — email or external support link

---

## Standalone Features by Phase

### Phase 1 — Core Tracking

- **Inbox/Ledger routing** — expenses go to inbox when any mandatory field is missing. When all mandatory fields are present and date is today or past, a ready indicator and Promote button appear. User taps Promote to move to ledger
- **Transaction creation** — via FAB command line or toolbar buttons
- **Transaction editing** — via Transaction Detail Modal
- **Transaction deletion** — swipe to delete (soft delete, tombstone)
- **Categories** — flat list, user-managed, income/expense type, color
- **Hashtags** — flat list, user-managed, sort order
- **Bank accounts** — multiple accounts, one currency each, color, visibility, running balance
- **Multi-currency** — PEN + USD (and any currency in `global_currencies`). Exchange rates from reference table, user-overridable per transaction. `amount_home_cents` cached and recalculated on `main_currency` change.
- **Descriptions** — write to `note_entries` via Universal Description Model. Data layer only — no Notes app UI required.
- **Bottom bar configurability** — show/hide tabs
- **Transactions sidebar configurability** — show/hide sections
- **CSV Import** — load transactions from external tools via `.csv` file

**CSV Import spec:**

Required columns (case-insensitive headers):
- `title` — transaction title (text)
- `amount` — positive decimal number, no currency symbols (e.g., `29.50`)
- `currency` — 3-letter ISO code (e.g., `USD`, `PEN`)
- `account` — bank account name; must match an existing account name or a new account is auto-created
- `category` — category name; must match existing or auto-created (e.g., `Food`, `Transport`)
- `date` — ISO 8601 format: `YYYY-MM-DD`

Optional columns:
- `hashtags` — comma-separated hashtag names without `#` (e.g., `lunch,work`)
- `exchange_rate` — decimal override for the exchange rate on this transaction; if omitted, system looks up the rate for that date from `exchange_rates`
- `notes` — plain text; stored as a `note_entry` linked to the transaction via `entity_links`

Import behaviour:
- Unknown categories are auto-created with a default colour
- Unknown bank accounts are auto-created in the specified currency
- Rows missing any required field are skipped and reported to the user as errors after import completes
- Import creates ledger records directly (not inbox) — imported records are treated as confirmed transactions
- Duplicate detection: a row is considered a duplicate if title + amount + date + account all match an existing ledger record; duplicates are skipped and reported
- The app shows an import summary: "X imported, Y skipped (errors), Z skipped (duplicates)"

### Phase 2 — Search & Filtering
- Category breakdown views with hashtag-level sub-grouping
- Filter by individual hashtag across categories
- Search across all expenses (title, description)

### UI Polish Pass 1 (after Phases 1–2)

A dedicated refinement pass over all existing screens before adding new feature complexity. No new features — only visual and interaction quality improvements.

- **Spacing & alignment** — audit every screen against the 4pt grid; fix inconsistencies
- **Transitions & animations** — smooth navigation transitions, list insertion/deletion animations, FAB open/close
- **Empty states** — polished empty state illustrations/messages for inbox, ledger, search results, category views
- **Loading states** — skeleton views or shimmer placeholders where data loads asynchronously
- **Error states** — consistent error banners, retry affordances, offline indicators
- **Dark mode** — audit every screen for contrast, readability, and color token correctness in dark mode
- **Accessibility** — VoiceOver labels, Dynamic Type support, sufficient contrast ratios
- **Micro-interactions** — haptic feedback on key actions (promote, delete, FAB tap), pull-to-refresh feel
- **Typography & color consistency** — verify all text uses SharedUI typography tokens, all colors use SharedUI color tokens
- **Platform conventions** — swipe actions, context menus, keyboard shortcuts (iPad), scroll behavior

### Phase 3 — Reconciliation
- Batch creation, assignment, completion, un-reconcile
- Field-locking on completed batches
- `cleared` flag toggleable on individual transactions

### Phase 4 — People & Transfers
- `/` syntax for paired transactions (people splits and inter-account transfers)
- Person accounts (`is_person = true`) auto-created on first use per currency
- @Debt category auto-assigned to person side; @Other for inter-account transfers
- Debt balances between people converge to zero naturally as transactions are entered. A "settlement" is simply a person-to-person transaction with an amount that brings the outstanding balance to zero.
- People section in Transactions sidebar with running balances
- Cross-user sharing via `linked_user_id` invitation, `transaction_shares`, two-party confirmation flow

### Phase 5 — Expense Planning + Recurrence Engine
- Expense Planning section in Transactions sidebar (read-only filtered list of future-dated transactions where `date > today`, linked to a `todo_task`)
- Users create planned expenses through the normal FAB by setting a future date — this automatically routes the transaction to the Planning view and creates a linked task. There is no separate creation form in the Planning view itself.
- Overdue section (planned expenses past their due date)
- Recurring expense templates (`is_recurring = true`)
- Register/confirm planned expense → promotes to ledger with completion date
- Recurrence engine built as shared infrastructure (reused by To-Do app)

### Phase 6 — Polish & Utilities
- Receipt photos — camera/image picker → Supabase Storage upload → `receipt_photo_url` stored on transaction. Editable post-reconciliation.
- CSV Export — export all transactions as a flat CSV file with columns: date, title, amount, currency, category, account, hashtags, notes.

---

## Ecosystem Features

### What this app writes to shared tables (from day one)

| Action | Shared table written |
|---|---|
| User adds a description to any transaction | `note_entries` (via Universal Description Model) + `entity_links` |
| Any expense created, edited, or deleted | `activity_log` |
| Any cross-app link created or soft-deleted | `entity_links` |

### What is explicitly deferred

| Feature | Deferred to |
|---|---|
| Budget tracking UI and dashboard | Step 12 (Cross-App UI) |
| Slash command entry from Notes | Step 12 (Cross-App UI) |
| Voice and natural language entry | Step 13 (AI Layer) |

> Future-date routing is **not deferred** — it ships with Phase 5 (Expense Planning).

---

## Data Model

See System Architecture — Expense Tracker Tables, Shared Tables, and Entity Links Table for the complete schema.

**App-specific behavior notes:**
- Every transaction belongs to exactly one account, one category, zero or more hashtags
- Descriptions live in `note_entries`, never as a column on the transaction (Universal Description Model)
- Inbox and ledger are separate tables; `inbox_id` on a ledger record traces lineage
- Paired transactions share a `transfer_id`; person-side always gets @Debt or @Other automatically

---

## Edge Cases & Constraints

**Inbox promotion rules**
Mandatory fields for ledger: `title` (not 'UNTITLED'), `amount_cents`, `date` (today or past), `account_id`, `category_id`, `exchange_rate` (if account currency ≠ main currency). All must be present. When all mandatory fields are filled and date is today or past, the inbox item shows a ready indicator and a small Promote button. The user taps Promote to move the expense to the ledger — promotion is user-initiated, not automatic. This lets users add optional fields (hashtags, description, receipt photo) before promoting.

**Direct-to-ledger creation**
If all mandatory fields are provided at creation time and the date is today or past, the record bypasses the inbox entirely and lands directly in the ledger.

**Multi-currency**
Each account has exactly one currency (immutable after creation). Exchange rate auto-filled from `exchange_rates` reference table for the transaction date; user can override. `amount_home_cents` is a cached display value — always recalculated from `amount_cents × exchange_rate`. When `main_currency` changes in Settings, all `amount_home_cents` values recalculate.

**Reconciliation field-locking**
When a batch is completed, four fields lock on every included transaction: `title`, `amount_cents`, `date`, `account_id`. All other fields remain editable (category, hashtags, description, exchange rate, receipt photo, cleared). Un-reconciling reverts to draft and unlocks all four.

**Soft deletes everywhere**
No hard deletes on any mutable table. Deleting a transaction sets `deleted_at`. The sync engine propagates the tombstone to other devices. Deleting a hashtag tag from a transaction soft-deletes the junction row in `expense_transaction_hashtags`.

**Offline behaviour**
All writes succeed locally and immediately. Sync resolves in the background when connectivity is restored. The user is never blocked by a network condition. Sync errors are surfaced non-destructively — no data loss.

**Command line parsing**
The raw command text is stored as `source_text` on the transaction record. Parsing runs client-side on the device. Unrecognised tokens are ignored — partial input creates an inbox record with whatever fields were successfully parsed.

**Category system categories**
`@Debt` and `@Other` are system categories. They are visible in the category list but cannot be deleted or renamed. `@Debt` is always assigned `category_type = 'expense'`. Both default to 0 budget when budget mode is enabled.
