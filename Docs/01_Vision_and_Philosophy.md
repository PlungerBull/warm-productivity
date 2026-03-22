# Warm Productivity — Vision & Philosophy

**Version 1.0 — February 2026**

## What Is Warm Productivity?

Warm Productivity is a personal life ecosystem for everyone — a suite of interconnected apps that help people manage their money, tasks, and thoughts in one cohesive system. It starts with three core apps: an expense tracker, a to-do list, and a note-taking app. Each app works as a standalone tool, but together they form something greater: a personal operating system where actions in one app naturally flow into the others.

This is a product built for the general public. But it should feel personal — like it was made just for you. Every user should feel like they're the only person using it.

The name says it all. *Warm* because using it should feel like sitting at a clean desk with good light — calm, inviting, never stressful. *Productivity* because beneath the calm surface lives a capable system that handles real complexity when you need it to.

## Core Philosophy

### Simple by Default, Powerful When You Need It

Every feature starts simple. The surface is clean and approachable — anyone can pick it up and start using it without a tutorial. But beneath that simplicity, power-user features exist for those who want them. Complexity is never forced on you; it's revealed when you ask for it.

### Wholesome Minimalism

This isn't cold, sterile minimalism. It's warm. It's a UI that feels like it was designed by someone who cares about your day, not just your data. Every interaction should reduce stress, never add it. If a feature creates anxiety or pressure, it doesn't belong here.

### Zen UX — Things 3 Level of Restraint

Very little on screen at once. Every pixel earns its place. Animations are subtle and purposeful, never decorative. The interface breathes — generous whitespace, clear hierarchy, no visual noise. Inspired by Things 3's philosophy: powerful software that feels effortless.

### Your Data, Your Control

You own everything. The system supports a personal-first model: your data is yours, and sharing is always a deliberate choice, never a default. When collaboration features arrive, they follow the same principle — you share specific items with specific people, not workspaces.

### Schema-First, Core Flow First

The database schema is always complete from the start — all tables, all columns, all constraints, all relationships are deployed before any UI is built. Even if a feature won't have UI for months, its data model is already in place. No mid-development migrations, no schema surprises.

The UI is built in thin, testable slices. Each slice covers the absolute minimum core flow for its app. For the Expense Tracker, that means: create an expense, inbox/ledger routing, edit, delete. No photos, no CSV export, no dashboard — just the core data flow through a minimal UI. Only after that slice is hardened — locally tested, deployed to production, battle-tested with real use — does the next layer of UI get added on top of the already-stable foundation.

This matters because building fancy UI on top of untested foundations creates compounding problems. Every layer of complexity added before the core is solid makes bugs harder to find and fixes harder to make. Nail the core, then expand.

## The Ecosystem: How Apps Connect

Warm Productivity is not one app with tabs. It is three distinct apps — Expense Tracker, To-Do, and Notes — that share a common foundation and communicate deeply with each other.

### The Generative Principle

The defining feature of this ecosystem is that actions in one app create entities in another. This goes beyond simple linking. The apps are generative:

- **To-Do → Expense (optional):** A task can optionally carry financial data (amount, category, currency). When marked complete, it generates an expense entry. This is opt-in — most tasks (like "Brush teeth" or streak-tracked routines) have nothing to do with spending. Only tasks you explicitly configure with financial data trigger expense creation.
- **Every task and expense can have a linked note.** Notes live only in the notes table (DRY principle — no duplicate data). When a user writes a note on an expense or task, the note is created in the Notes app and linked back to the source. The note appears independently in the Notes app — searchable, browsable, connected to its source. Edits from either app update the same record.
- **Note → To-Do / Note → Expense:** From the Notes app, you can use slash commands to generate a to-do or expense directly. Eventually, AI will parse natural language to do this automatically (e.g., "I paid $20 today and need to pay $30 tomorrow" creates an expense and a future task).
- **Deletion is deliberate:** Items that exist across apps are tracked via a linking table. Deleting from one context gives you the choice: "remove from here" (removes the link, item survives elsewhere) or "delete everywhere" (removes all links and the item itself). If an item only exists in one place, it deletes directly.

### Connection Priorities

1. **Cross-app linking** — Items reference each other across apps. A note knows it came from an expense. A to-do knows it will generate one.
2. **Consistent family feel** — All three apps look and feel like siblings. Same visual language, same interaction patterns, same sense of warmth.
3. **Unified organizational model** — All three apps share the same two-layer organizational structure: flat categories (one per entity, structured, colored, sortable) and hashtags (multiple per entity, freeform, lightweight). Categories are for structured classification — they act as buckets where totals always add up cleanly (expense categories, to-do categories, notebooks). Hashtags are cross-cutting context filters (e.g., `#trip-to-paris`, `#tax-deductible`, `#shared-with-maria`) that provide additional dimensions without breaking the category structure. In breakdown views, transactions within a category are grouped by their exact hashtag combination so numbers sum to the category total. Each app's categories and hashtags are independent — an expense category "Food" and a to-do category "Food" are separate entities. The user learns one mental model and it works everywhere.
4. **Per-app dashboards** — Expense Tracker and To-Do each have their own dashboard tailored to their data. Notes is a simple app with no dashboard. No shared meta-dashboard.
5. **Unified search** — Search across all apps. Low priority — users will typically search within a single app. This is one of the last features to implement.

## The Three Apps

### Expense Tracker

Track what you spend, who owes whom, and where your money goes.

**Core Tracking:**

- Inbox/ledger structure: log any expense quickly (incomplete entries go to the inbox). When all mandatory fields are present and the date is today or past, the item shows a "ready" indicator and a small Promote button — the user taps it to move the expense to the ledger. This lets users add optional fields (hashtags, description, receipt photo) before promoting. Expenses can also be saved directly to the ledger, bypassing the inbox if all mandatory fields are present at creation time. The ledger enforces completeness — nothing is saved there without all required fields. Items in the ledger can still be edited. Expenses in the inbox can have notes attached.
- Flat categories (no hierarchy — every category is directly assignable to transactions)
- Hashtags on expenses (multiple per expense, freeform, available on both inbox and ledger items)
- Dates on every transaction
- Description on any expense (including inbox items) creates a linked note via the Universal Description Model — no duplicate data, description always lives in the Notes app
- Multiple bank accounts — each account has a single currency (a real-world multi-currency card is modeled as separate accounts, one per currency), with a simple total display per account
- Multi-currency support (PEN + USD minimum): exchange rates stored in a single-base reference table (all rates relative to USD: `1 USD = X other currency`), manually maintained initially, automated via external API later. The reference table auto-fills exchange rates when creating transactions, but the user can override with their actual rate (because real-world rates vary by vendor — street exchange, bank, app). Original transaction amounts are always immutable in the account's currency. `amount_home_cents` is a cached display value that recalculates when the user changes their `main_currency`. Cross-currency transfers (e.g., PEN account → USD account) use the implied rate derived from the two real amounts so transfers always net to zero on dashboards.
- Receipt photo attachment
- CSV import and export

**Dashboard & Analysis:**

- Simple table showing expenses by category per month, 3-month view
- Category breakdown views with hashtag combination grouping (rows sum cleanly to category total)
- Filtering by individual hashtag across categories (e.g., all expenses tagged `#trip-to-paris`)
- Search across expenses
- Budget tracking: monthly per-category budgets for both income and expense categories. Each category has a `category_type` ('income' or 'expense') that determines which section it appears in on the dashboard. All-or-nothing — when activated, every category must have a budget. Static template that repeats monthly (no rollover, no auto-adjustment). @Debt defaults to 0 budget. Set in main_currency, compared against actual spending across all accounts. Dashboard table shows budget vs. actual per category, split into income and expense sections.

**Financial Integrity:**

- Reconciliation: match expenses against bank statements via reconciliation batches, managed from a dedicated section in the Expense Tracker sidebar. When a batch is completed, four fields lock on all included transactions: original amount, bank account, title, and date. All other fields (category, notes, exchange rate, receipt photo) remain editable. Batches can be un-reconciled (reverted to draft), which unlocks all fields. Transactions are assigned to batches via the transaction menu, not from the reconciliation section.

**People & Transfers (unified `/` syntax):**

- People are bank accounts with `is_person = true` — no separate people table. The `/` syntax creates a paired transaction on any account (person or real).
- Shared expense: `-60 Lunch @Food $Chase /Eliana +30` → -60 on Chase (@Food), +30 on Eliana (@Debt). Eliana owes you 30.
- Settlement: `+30 Settlement @Food $Chase /Eliana -30` → Eliana's balance returns to 0.
- Someone else pays: `-30 Lunch @Food $Eliana` → single transaction on Eliana's account. You owe her 30.
- Inter-account transfer: `-60 Exchange $Chase /Chase_Credit +60` → same mechanism, category @Other for both.
- People section in the sidebar showing each person's running balance, grouped by name across currencies
- **Cross-user sharing (via invitation):** Link a person account to a real Warm Productivity user. Once linked, shared expenses are visible to both parties — the receiver sees the same transaction sign-flipped (your +30 becomes their -30). No duplication or syncing — one transaction record, two readers. Each user has their own category and notes. Both parties must confirm the transaction (amount, title, currency, date) before those fields lock. Any edit before confirmation resets the other party's agreement. Managed via `transaction_shares` table.

**Expense Planning:**

- View all upcoming planned expenses (recurring and one-off) sorted by due date, with one row per recurring expense (next occurrence only)
- Create planned expenses directly from the Expense Tracker — both recurring and one-off
- Register/confirm planned expenses when they happen, triggering the standard expense generation flow
- Future-date routing: adding an expense with a future date automatically creates a planned expense instead of a real expense
- Leverages the shared recurrence engine (built as ecosystem infrastructure alongside the Expense Tracker, reused by the To-Do app for recurring tasks)

**AI-Powered Entry:**

- Voice and natural language expense entry

### To-Do

Manage tasks, track streaks, and let completions trigger real actions. Inspired by TickTick and Todoist.

**Core Task Management:**

- Task creation with: title, description (creates a linked note via Universal Description Model), due date, priority (4 levels), categories, hashtags
- Quick-add with natural parsing: `@Category`, `#hashtag`, `!priority`, natural date/time — everything else becomes the task title
- Smart filters as primary navigation: Today, This Week, Upcoming, No Date, Overdue — each with sort/group options (by category, priority, date)
- Configurable sidebar: categories and hashtags as clickable filters, any section can be shown or hidden

**Recurring Tasks & Subtasks:**

- Recurring tasks with flexible patterns (daily, weekly, specific days, monthly, yearly, custom intervals) — next occurrence calculated from due date or completion date (user chooses per task)
- One-level subtasks with two completion modes: independent (parent completable anytime) or gated (all subtasks must be done first)

**Streaks:**

- Any task can optionally enable streak tracking — streaks are a feature on tasks, not a separate entity. Set a frequency (daily, weekly, monthly), a goal type (achieve it all or reach a numeric target), and a recording method (auto-tap, manual entry, or complete all). The "Streaks" section in the To-Do app is a filtered view showing all streak-enabled tasks with their current streak count, today's progress, and goal status. Streaks auto-reset when a period ends without the goal being met — no manual marking needed. Calendar/history views showing fulfilled vs. missed periods are a future addition.

**Expense Connection:**

- Optional financial data on tasks (amount, category, currency) that generates an expense on completion

**Collaboration:**

- Share tasks with others, assign responsibility

**AI-Powered Entry:**

- AI-powered task creation from voice or natural language

### Notes

Capture thoughts, and let them connect to everything else.

**Three-panel layout:**

- **Left panel — Notebooks:** organizational containers for notes (like "Work", "Personal", "Health"), each with a display color for visual identification. No "All Notes" view — you always enter through a specific notebook or the Inbox. The **Inbox** is a virtual view (not a real notebook) showing all notes with no notebook assignment — including auto-generated notes from expenses/to-dos. The Inbox cannot be renamed or deleted. Each note belongs to one notebook (or none, in which case it lives in the Inbox). Deleting a notebook deletes all notes in it. Notebook assignment via `@NotebookName` in the title field.
- **Middle panel — Note list:** scrollable list showing `DD/MM: TITLE`, newest-first by default with configurable sort order. Filtered by whatever notebook is selected.
- **Right panel — Note content:** full markdown rendered view, immediately editable on click. Linked references showing which expense or to-do a note is connected to (if applicable).

**Single source of truth (DRY):** Notes live only in the notes table — there is no `notes` column on expenses or tasks. When a user writes a note on an expense, the system creates a note record and links it to the expense. Both apps read from and edit the same record. Deletion is per-context: "delete only in this app" hides or unlinks the note from one app while preserving it in the other; "delete everywhere" removes the note and all links (with a warning).

**Core Note-Taking:**

- Note creation with automatic date stamping (date is modifiable after creation)
- Three-panel layout with notebooks, note list, and content editor
- Full markdown support, immediately editable
- Notes generated from expenses appear in the Inbox automatically, with linked references back to their source. Users can move them to any notebook.
- Hashtags on notes (multiple per note, freeform) — same cross-cutting context model as the other two apps
- Pinning important notes to the top of their notebook (not available for Inbox notes)
- Search across all notebooks by title and content
- New note button on sidebar — creates in the currently selected notebook, or Inbox if none selected
- Onboarding template note on first launch explaining the app

**Slash Commands:**

- Quick capture commands within notes: `/expense -30 Lunch yesterday @Food $BCP_PEN` and `/todo Buy groceries tomorrow @Personal #Errands`
- Slash commands show an inline preview card for confirmation before creating the entity — prevents phantom entries from typos
- `/expense` displays as a clean styled line (e.g., `-30.00 Lunch`); `/todo` displays as an interactive checkbox with a date tag (e.g., `[ ] Buy groceries` with a `Today` badge). Symbol convention: `@` categories/notebooks, `#` hashtags, `$` primary bank account, `/` paired transaction target account (any account — person or real) in Expense Tracker and slash commands in Notes, `+`/`-` amount sign prefixes.
- Objects sidebar section in Notes lists all entities created from slash commands across all notes
- Turns the Notes app into a quick-entry hub for the ecosystem

**Export:**

- Export per notebook: each notebook exports as a single consolidated `.md` file with all its notes separated by date headers.

**Collaboration:**

- Shared notes with other users

**AI-Powered Entry:**

- AI-powered natural language parsing (write a note, have the system extract expenses and tasks from it)

## Design System Direction

The visual identity of Warm Productivity should feel approachable, clean, and — above all — warm.

### Color Philosophy

- **Base:** Clean white. The canvas is bright and open, never dark or heavy by default.
- **Primary accent:** Brick orange. This is the warmth. Used for primary actions, active states, and key UI elements. It should feel confident but not loud.
- **Supporting palette:** Warm grays and soft neutrals for text, borders, and backgrounds. No cold blues or stark blacks unless needed for contrast.
- Light-first design with dark mode available as an option. Dark mode should preserve warmth — dark warm grays, not pure black.

### Typography & Spacing

- Clean, readable typeface. Nothing decorative.
- Generous whitespace everywhere. The interface breathes.
- Clear typographic hierarchy: you should be able to scan any screen and understand its structure instantly.

### Interaction & Animation

- Animations are subtle and functional: transitions that orient you, feedback that confirms actions.
- Nothing bounces, wobbles, or draws attention to itself.
- Speed matters: the interface should feel instant. If something takes time, show progress honestly.

### Iconography

- Simple, consistent line icons. Friendly but not playful.
- Icons support text, they don't replace it. Clarity over cleverness.

### Inspiration

- **Things 3** for restraint and focus
- **Todoist** for clean structure and visual tone
- **YNAB** for making complex financial data feel approachable
- **Notion** for showing that powerful tools can still feel calm
- **Claude (Anthropic)** for warm, conversational UI that feels human and approachable without sacrificing capability

## Future Vision

### AI Layer

Warm Productivity will eventually include AI capabilities, but AI is a tool in service of the user, never the other way around.

- **Voice assistant:** Both task-oriented ("log a $30 expense for lunch") and conversational ("what did I spend most on last month?"). The assistant understands context across all three apps.
- **Natural language parsing:** Write a note in plain language and the system extracts structured data — expenses, tasks, dates, amounts — and creates them with your confirmation.
- **Smart suggestions:** The system learns your patterns and offers gentle nudges, never nagging reminders.

### Collaboration

Collaboration follows the ownership model: you share specific items, not workspaces.

- **Expenses:** Tag people on expenses with `/PersonName`, track who owes whom via virtual accounts, maintain running balances. When people are linked to real users, shared expenses push to their app.
- **To-dos:** Share tasks with others, assign responsibility.
- **Notes:** Share individual notes with specific people.

### Extensibility

The ecosystem is designed to grow. The architecture supports adding new apps in the future — a calendar, a journal, a reading list — each plugging into the same shared foundation and following the same generative principle.

## Business Model

**Freemium with paid tiers.** Every user gets a 1-month free trial with full access. After that, a subscription unlocks the full experience.

- **Pricing tiers and feature gating** to be defined as the product matures.
- **Payment:** Apple In-App Purchases for iOS, with platform-appropriate payment methods added as new platforms launch.
- **Launch strategy:** iOS-first, starting with a small group of beta testers before opening to the public.
- **Platform roadmap:** iOS → macOS → Windows → Browser. Android is not in the current roadmap but the architecture does not preclude it.

## What Warm Productivity Is Not

- **Not a corporate tool.** This is personal-first. It's designed for people's lives, not company workflows. It should feel like it was made for each individual user.
- **Not a dashboard of dashboards.** The apps are primary. The connections between them are organic, not forced through a central hub.
- **Not feature-bloated.** If a feature doesn't serve the core experience, it doesn't ship. Simplicity is protected fiercely.
- **Not cold or clinical.** Every design decision should pass the warmth test: does this make the experience feel more human or less?

---

*Warm Productivity — Calm tools for a full life.*
