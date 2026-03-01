# Warm Productivity — Development Roadmap

**February 2026 — v3**

## What Is This Document?

This is the step-by-step plan for building the Warm Productivity ecosystem from scratch. Follow it top to bottom. Each step tells you what to produce, what it should contain, and why it matters for everything that comes after.

## Before You Start: The Docs vs. Code Principle

Not everything deserves a document. Before creating anything, apply this rule:

- **Put it in a document** if it's abstract, forward-looking, or can't be inferred from the codebase (vision, architectural reasoning, cross-app plans, decision history, AI workflow guidance)
- **Put it in the code** if it's practical and self-evident from well-written code (data definitions via schema comments, coding conventions via folder structure and linter configs, design tokens via CSS/theme variables)
- **Put it in a Claude skill** if it's a repeatable pattern for AI-assisted tasks (component creation, schema changes, scaffolding, testing)

This keeps your documentation lean and avoids conflicting sources of truth.

## The Build Principle: Schema-First, Core Flow First

This principle governs how every app is built. It applies to Steps 7, 9, and 11 (the app build steps).

**1. Deploy the complete database schema first.** All tables, all columns, all constraints, all relationships — even for features that won't have UI for months. The schema is the foundation. No mid-development migrations, no schema surprises. If the data model is wrong, you want to find out before any UI depends on it.

**2. Build the thinnest possible UI for the core flow.** Each app has one core flow that defines what it *is*. Build only that flow first, with the simplest UI that exercises it. No fancy design, no secondary features, no polish. Examples:

- **Expense Tracker core flow:** Create expense → inbox/ledger routing (automatic promotion based on field completeness for standalone expenses) → edit → delete. Categories, hashtags, descriptions, dates, multiple bank accounts (with per-account total display), multi-currency (PEN + USD), exchange rates manually maintained. CSV import (for loading data from other tools). No Expense Planning (Phase 6), no receipt photos, no CSV export, no dashboard, no reconciliation, no search/filtering.
- **Notes core flow:** Create note → edit with markdown → assign to notebook → timeline view (date: title, newest-first) → pinning → search across notebooks → delete. No slash commands, no export. This is a simple app — the core flow covers most of its functionality.
- **To-Do core flow:** Create task → set due date and priority → categories → hashtags → complete → delete. No subtasks, no recurring, no streaks, no smart filters beyond a basic list, no expense connection.

**3. Harden before expanding.** The core flow must be locally tested, deployed to production, tested in real deployment, and confirmed stable before adding any secondary features. Building on shaky foundations makes everything harder — for you and for the AI writing the code.

**4. Layer features one at a time.** After the core is solid, add the next feature slice. Test it. Harden it. Then add the next. Each layer builds on a proven foundation.

**5. Standalone first, cross-app UI last, AI last of all.** Each app is built as a fully functional standalone tool before any cross-app UI integration happens. The distinction is between data layer and UI:

- **Data layer (immediate):** Writing to shared tables (`note_entries`, `entity_links`, `activity_log`) happens from day one. The schema is deployed upfront, and apps write to shared tables as part of their standalone functionality. An expense description creating a `note_entry` is data-layer work — it doesn't require the Notes app UI to exist.
- **Cross-app UI (deferred):** Any feature where one app's UI surfaces or interacts with another app's data is deferred until all three standalone apps are complete. This includes: slash commands in Notes, Expense Planning showing task due dates, task→expense generation UI, cross-app linked references, dashboards, and budget tracking. Note: each app's own activity view (filtered by entity_type) is part of its standalone build, not cross-app UI.
- **AI features (last):** Voice entry, natural language parsing, and AI-powered creation across all apps come after cross-app UI integration is complete. AI depends on everything else being stable.

## Step 1: Write the Vision & Philosophy Document

**What you're producing:** A single markdown document that serves as the north star for the entire ecosystem.

**Why it comes first:** Every decision downstream — architecture, tech stack, UI patterns, even database naming — should be testable against this document. Without it, each app drifts in its own direction.

**What it should contain:**

- Core philosophy and mission (wholesome minimalism, zen UX, total user control)
- What the ecosystem is and what it is not
- Design principles and user experience philosophy
- Design system direction: color philosophy, typography approach, spacing and density principles, animation philosophy, iconography style
- Note: the actual design tokens and values will live in code as theme variables later — this doc captures the *why* behind them

**Done when:** You can read it and confidently answer "does feature X belong in this ecosystem?" for any hypothetical feature.

## Step 2: Write the System Architecture Document

**What you're producing:** The structural blueprint for how the entire ecosystem is built and how apps relate to each other.

**Why it comes second:** You need the vision locked in before making structural decisions, but you need the structure locked in before choosing tools or writing specs.

**What it should contain:**

- High-level system diagram (apps, shared layers, database)
- Shared database schema design and relationship patterns
- Cross-app data model (shared categories, tags, linking strategy)
- Extension points: how a future new app plugs into the ecosystem
- Authentication and user management strategy
- Tech stack choices and rationale (framework, database, deployment — keep the choices brief, the reasoning is the value)
- Data flow patterns between apps

**Done when:** A developer (or AI) could read this and understand how to add a fourth app to the ecosystem without breaking anything.

## Step 3: Write the Cross-App Integration Map

**What you're producing:** A focused, practical reference that defines every touchpoint between apps.

**Why it comes third:** The Architecture doc explains the structure. This doc answers the practical question: "I'm building app X — what exactly do I need to hook into?" You need this before building app #1 so you build the right hooks from day one.

**What it should contain:**

- For each app pair: what data is shared, what events are emitted/consumed, what UI surfaces link between apps
- The shared entity model (how an expense, task, and note can reference each other)
- What each app exposes to the ecosystem vs. what it keeps private
- Planned integration points for apps that don't exist yet (so you build hooks before you need them)

**Done when:** You could hand this to someone building app #2 and they'd know exactly what to connect to without reading the app #1 codebase.

## Step 4: Build the Claude Skills Library

**What you're producing:** A set of focused, reusable instruction files that encode your conventions into guidance Claude can follow automatically.

**Why it comes fourth:** You now have the vision, architecture, and integration plans defined. Skills translate those decisions into repeatable actions so Claude doesn't need to re-learn your standards every session.

**What skills to build:**

- **Database Schema** — How to add/modify tables, migration patterns, cross-app relationship rules
- **Multi-Currency** — Handling multi-currency amounts, exchange rates, and home currency conversion
- **Component Creation** — UI component patterns, styling approach, folder structure, naming conventions
- **App Scaffolding** — Generate initial project structure from an app spec following ecosystem conventions
- **Testing** — Test structure, coverage expectations, cross-app integration testing patterns
- **Documentation Sync** — How to keep docs current as the codebase evolves, preventing doc drift
- **Sync Engine** — Delta sync implementation, version tracking, and conflict resolution
- **Entity Links** — Cross-app linking, entity_links table, and Universal Description Model

**Key principle:** Each skill should be focused on one type of task. A giant "build my app" skill is less effective than several focused skills that each handle one thing well.

**Done when:** You can say "create a new component" or "add a table to the schema" and Claude produces output that matches your conventions without additional explanation.

## Step 5: Write the CLAUDE.md

**What you're producing:** The project-level instruction file that Claude reads automatically when working in your codebase. This is the distilled, actionable cheat sheet for every AI session.

**Why it comes fifth:** It synthesizes everything from Steps 1–4 into a single entry point. You need the source documents written first so you know what to distill.

**What it should contain:**

- Project structure overview (what lives where, shared vs. app-specific folders)
- Key schema conventions and relationship patterns
- Naming patterns and anti-patterns to avoid
- How to add a new app to the ecosystem (step-by-step checklist)
- Pointers to the full docs and skills when deeper context is needed
- AI workflow guidance: which skills to use for which tasks, how to load context for different types of work

**Important:** This document evolves. After completing each app, update it with lessons learned and new conventions that emerged. It absorbs what would otherwise be a standalone "AI Development Playbook."

**Done when:** Claude can start a coding session with only the CLAUDE.md loaded and produce work that's consistent with your ecosystem standards.

## Step 6: Write the Expense Tracker App Spec

**What you're producing:** The detailed specification for the first app. This is also the template that all future app specs will follow.

**Why it comes sixth:** All foundation documents are in place. You know the vision, the architecture, the integrations, and the AI workflow. Now you define what to actually build first.

**What it should contain:**

1. **Context Loading Guide** — Which documents and skills to load for dev sessions on this app (goes at the very top)
2. **App Overview** — What it does, core value proposition
3. **Standalone Features** — Everything it does on its own
4. **Ecosystem Features** — How it connects to other apps, shared data it reads/writes
5. **Data Model** — App-specific tables, relationships to shared schema
6. **Screens & Flows** — Key screens, navigation paths, user journeys
7. **Edge Cases & Constraints** — Multi-currency handling, offline behavior, etc.

**Done when:** You could hand this spec to Claude and it would know exactly what to build, how it fits into the ecosystem, and which docs/skills to reference.

## Step 7: Build App #1 — Expense Tracker + Shared Infrastructure

**What you're producing:** The first working app AND the shared foundation that all future apps will inherit.

This step is unique because you're building two things at once: the expense tracker itself and the ecosystem infrastructure.

**Shared infrastructure to build alongside the app:**

- Authentication and user management system
- Shared navigation shell and app switcher
- Common flat category + hashtag system used across all apps
- Shared UI component library (buttons, inputs, modals, layouts)
- Database connection layer and shared utilities
- Recurrence engine (built during Phase 5 — shared date calculation, schedule anchoring, next-occurrence logic reused by To-Do app)
- Base deployment pipeline

**Standalone phases (each phase hardens before the next begins):**

- **Phase 1 — Core Tracking:** Expenses (inbox/ledger, automatic promotion for standalone expenses when all mandatory fields present and date is today/past), categories, hashtags, dates, descriptions (writes to `note_entries` via Universal Description Model — data layer, no Notes UI needed), multiple bank accounts (with per-account total display), multi-currency (PEN + USD), exchange rates via single-base reference table (all rates relative to USD, manually maintained, auto-filled on transactions but user-overridable), `amount_home_cents` as cached display value that recalculates on `main_currency` change, CSV import (for loading data from other tools). No receipt photos (Phase 6), no CSV export (Phase 6), no dashboard, no reconciliation, no search/filtering.
- **Phase 2 — Search & Filtering:** Category breakdown views with hashtag combination grouping, filtering by individual hashtag across categories, search across expenses.
- **Phase 3 — Reconciliation:** Mark/tag expenses as reconciled against bank statements. Reconciled items become locked.
- **Phase 4 — People & Transfers (unified `/` syntax):** People are bank accounts (`is_person = true`). The `/` syntax creates paired transactions on any target account — people or real accounts. Person accounts auto-created on first use in a new currency. @Debt category for people splits, @Other for inter-account transfers. Settlement flow, People section in sidebar with running balances. All linked via `transfer_id`. Cross-user sharing via invitation: link person accounts to real Warm Productivity users (`linked_user_id`), `transaction_shares` table for shared visibility, sign-flipped display for receivers, independent categories and notes per user, two-party confirmation flow that locks amount/title/currency/date once both agree, edit gatekeeper database function.
- **Phase 5 — Expense Planning + Recurrence Engine:** Builds the recurrence engine as shared infrastructure (date calculation, schedule anchoring, next-occurrence logic) — reused later by the To-Do app for recurring tasks. Expense Planning section (filtered view of inbox: records with `linked_task_id`, sorted by linked task's `due_date`) showing recurring and one-off planned expenses. Overdue section (subset where linked task's due date is today/past and task not completed). Create planned expenses directly (with linked tasks for scheduling, `date = null` on inbox, due date on task). Register/confirm planned expenses to promote to ledger with completion date. Recurring expense template management. Schedule anchoring configurable per recurrence rule (anchor to original schedule or from last completion). No skip/pause — user either keeps or deletes a recurring expense.
- **Phase 6 — Polish & Utilities:** Receipt photos (camera/image picker → upload to Supabase Storage → store URL as `receipt_photo_url` on inbox and ledger transactions, editable post-reconciliation). CSV export (export transactions from the ledger as a `.csv` file for external tools or backups).

**Deferred to cross-app UI integration (Step 12):** Dashboard, budget tracking, future-date routing.
**Deferred to AI layer (Step 13):** Voice and natural language expense entry.

**Documents to load per session:**

- CLAUDE.md (automatic in Claude Code)
- Vision & Philosophy
- System Architecture
- Cross-App Integration Map
- Expense Tracker App Spec
- Relevant Claude Skill for the current task

**When you're done:** Update the CLAUDE.md with new conventions that emerged, start the Changelog with any deviations from the original plan, and run the Documentation Sync skill.

## Step 8: Write the Notes App Spec

**What you're producing:** The specification for the second app, following the same template from Step 6.

**Why Notes comes second:** Notes is the simplest app, so building it second gives you a finished two-app ecosystem sooner. It also acts as a proving ground for cross-app integration in a simpler context — expense notes sync immediately, and slash commands for creating expenses are live. This tests the generative principle before tackling the more complex To-Do connections.

**Key integration points to define:**

- How expense notes appear in the Notes app automatically
- Slash command syntax for creating expenses from within notes
- Linked references back to source expenses

## Step 9: Build App #2 — Notes

**What you're producing:** The second app, integrating into the existing shell and database.

Notes launches with content already in it — all the notes created as expense descriptions during App #1 populate automatically in the Inbox. The Notes app is built as a standalone tool first; slash commands and cross-app UI are wired up in Step 12.

**Standalone phases (each phase hardens before the next begins):**

- **Phase 1 — Core Notes:** Create note, edit with markdown, assign to notebook, hashtags, timeline view (date: title, newest-first), pinning, search across notebooks, delete. Auto-generated notes from expense descriptions (created during Expense Tracker Phase 1) are already present in the Inbox. This is a simple app — the core flow covers most of its functionality.
- **Phase 2 — Export:** Per-notebook export as consolidated `.md` file.

**Deferred to cross-app UI integration (Step 12):** Slash commands (`/expense`, `/todo`), Objects sidebar section, cross-app linked references UI.
**Deferred to AI layer (Step 13):** AI-powered natural language parsing (extracting expenses and tasks from notes).

**Documents to load per session:**

- CLAUDE.md (updated after App #1, now richer with real conventions)
- Cross-App Integration Map (defines how notes connect to expenses)
- Notes App Spec
- Relevant Claude Skill for the current task
- System Architecture — only if working on shared schema changes

**When you're done:** Update the CLAUDE.md, update the Changelog, run the Documentation Sync skill.

## Step 10: Write the To-Do List App Spec

**What you're producing:** The specification for the third and final initial app.

**Why To-Do comes last:** By this point, both Expenses and Notes exist. Every integration point is live from day one — task notes sync immediately to the Notes app, the optional expense generation works immediately, everything connects. The To-Do app benefits from lessons learned across two full app builds.

**Key integration points to define:**

- How tasks link to expenses (optional financial data that generates expenses on completion)
- How task notes sync to the Notes app
- Shared categories and tags for cross-app filtering
- Slash commands in Notes for creating tasks

## Step 11: Build App #3 — To-Do List

**What you're producing:** The third app, completing the initial ecosystem.

By this point, adding a new app should be a well-practiced process. The CLAUDE.md and skills carry most of the institutional knowledge. The To-Do app is built as a standalone tool first — cross-app connections (expense generation, slash commands) are wired up in Step 12.

**Standalone phases (each phase hardens before the next begins):**

- **Phase 1 — Core Tasks:** Create task, set due date and priority, categories, hashtags, descriptions (writes to `note_entries` via Universal Description Model — data layer), complete, delete. Quick-add command syntax: `[title] [@category] [#hashtag] [!priority] [date]`. No subtasks, no recurring, no streaks, no expense connection.
- **Phase 2 — Subtasks:** One level of nesting only. Independent completion mode (parent completable anytime) or gated mode (all subtasks must be done first).
- **Phase 3 — Recurring Tasks:** Recurrence rules (daily, weekly, specific days, monthly, yearly, custom) and schedule anchoring. Reuses the shared recurrence engine built during Expense Tracker Phase 5.
  > **⚠ Dependency:** To-Do Phase 3 cannot begin until Expense Tracker Phase 5 (Recurrence Engine) is complete. The shared recurrence engine is built in Expense Tracker Phase 5 and reused here.
- **Phase 4 — Streaks:** Enable streak tracking on any task via `streak_frequency`. Configuration: frequency (daily/weekly/monthly), goal type (achieve_all/reach_amount), goal value (for reach_amount), recording method (auto/manual/complete_all). Streaks section as filtered view of streak-enabled tasks. `streak_completions` table for progress logging. Auto-unachieve via scheduled Edge Function at period boundaries.
- **Phase 5 — Expense Connection (data layer):** Edge Function built immediately. Task → expense generation on completion (`has_financial_data`, `linked_inbox_id`). Financial fields visible read-only in Task Detail Modal. Full expense connection UI deferred to Step 12.
- **Phase 6 — Collaboration:** Share tasks with others, assign responsibility.

**Deferred to cross-app UI integration (Step 12):** Expense connection full UI (financial fields on tasks, linked inbox display, Expense Planning view in To-Do).
**Deferred to AI layer (Step 13):** AI-powered task creation from voice or natural language.

**Documents to load per session:**

- CLAUDE.md (now contains lessons from two full app builds)
- Cross-App Integration Map (defines links to both previous apps)
- To-Do List App Spec
- Relevant Claude Skill for the current task
- System Architecture — only if working on shared schema changes
- Expense Tracker App Spec — only as reference when touching integration points

**When you're done:** Update the CLAUDE.md, update the Changelog, run the Documentation Sync skill.

## Step 12: Cross-App UI Integration

**What you're producing:** The UI features that bridge apps — everything that requires one app's interface to surface or interact with another app's data. All three standalone apps must be complete before this step begins.

**What to build:**

- **Expense Tracker:** Dashboard (expenses by category per month, 3-month view), budget tracking (monthly per-category budgets for income and expense categories, all-or-nothing, static template, @Debt defaults to 0, set in main_currency, budget vs. actual dashboard table), future-date routing (future-dated expenses auto-create planned expenses with linked tasks)
- **Notes:** Slash commands (`/expense`, `/todo`) with simplified bottom sheet registration flow and confirmation flow, Objects sidebar section, cross-app linked references UI ("Linked to expense: Lunch at Noma")
- **To-Do:** Expense connection UI — financial fields on tasks (`has_financial_data` + `linked_inbox_id`), task→expense generation on completion, "Generated expense" indicator on completed tasks
- **Cross-cutting:** Cross-app search and filtering (low priority — users typically search within a single app), data export and backup across the ecosystem, performance optimization and UX polish

**Pre-Launch: Pricing & App Store Setup**
Before submitting any app to the App Store, define the monetisation model: free tier limits, paid tier features, pricing (one-time or subscription), and whether it is per-app or a bundle. This does not affect the build — defer until all three apps are feature-complete and tested. The goal is to test the apps fully before deciding what to charge for.

## Step 13: AI Layer

**What you're producing:** AI-powered features across all three apps. This comes last because AI depends on all standalone and cross-app features being stable — it needs to understand the full data model and all integration points.

**What to build:**

- **Expense Tracker:** Voice and natural language expense entry
- **Notes:** AI-powered natural language parsing (write a note, have the system extract expenses and tasks from it)
- **To-Do:** AI-powered task creation from voice or natural language
- **Cross-cutting:** Voice assistant that understands context across all three apps, smart suggestions based on user patterns

## Living Documents: The Changelog

Throughout all steps, maintain a simple running decision log. This is the only document that's append-only — everything else gets updated in place.

**Format:**

- Date
- What changed
- Why
- Which documents or code areas were affected

**Why it matters:** Without this, future AI sessions work from outdated docs and make decisions based on plans you've already revised.

---

*Warm Productivity — Building the future, one app at a time.*
