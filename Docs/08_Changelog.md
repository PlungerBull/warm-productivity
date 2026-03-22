# Warm Productivity — Changelog

This is the project decision log. Append-only — never edit or delete past entries. Every session that produces a meaningful decision, schema change, or design revision should add an entry.

**Format:**
- **Date** — YYYY-MM-DD
- **What changed** — brief description
- **Why** — the reasoning
- **Affected documents** — which files were modified

---

## 2026-03-01

**What changed:** Initial documentation suite completed.
**Why:** Planning phase finished — Vision, System Architecture, Cross-App Integration Map, CLAUDE.md, and all three app specs written and audited.
**Affected documents:** All documents in ProjectPlan/.

---

**What changed:** To-Do phases split — Phase 2 (Subtasks) and Phase 3 (Recurring Tasks) are now separate phases. Phase 5 Expense Connection defined as data layer only. Phase 6 Collaboration added.
**Why:** Phases were bundled in Roadmap but treated as separate in the To-Do spec. Separated for clarity and correct dependency tracking.
**Affected documents:** warm-productivity-todo-app-spec.md, warm-productivity-development-roadmap.md

---

**What changed:** Recurrence schema updated — removed `custom` pattern, added `day_of_month` (integer), `week_of_month` (integer), `anchor` enum (fixed / after_completion).
**Why:** `custom` was undefined. New fields enable monthly-by-date ("every 15th"), monthly-by-position ("every 2nd Tuesday"), and floating/after-completion patterns — matching Todoist and Things 3 feature sets.
**Affected documents:** warm-productivity-system-architecture.md

---

**What changed:** Exchange rate behaviour clarified — `amount_home_cents` recalculates immediately when user edits `exchange_rate` on a transaction. Global rate table updates never retroactively modify existing records.
**Why:** Confirmed that each transaction is bound to its historical rate. The schema already supported this; documentation was ambiguous.
**Affected documents:** warm-productivity-system-architecture.md

---

**What changed:** Sidebar design for Expense Tracker clarified — flat list with inline amounts, no Reconciliation section in sidebar, People rows are per virtual account (one per currency), amount fields use amount_home_cents except People which uses original currency amounts.
**Why:** UI design was described inconsistently. User clarified the intended behaviour.
**Affected documents:** warm-productivity-expense-tracker-app-spec.md

---

**What changed:** CLAUDE.md updated — added MVVM + Repository pattern, SwiftData + App Groups note, SharedUI package definition with full design token list, corrected project structure to match System Architecture, corrected skills build order (multi-currency moved to #2).
**Why:** Architecture and coding conventions were described in System Architecture but not carried into CLAUDE.md for the build phase.
**Affected documents:** CLAUDE.md

---

**What changed:** Company/organization mode fully removed from documentation.
**Why:** After designing the schema layer, decided company mode should be a separate product rather than an extension of personal productivity apps.
**Affected documents:** warm-productivity-system-architecture.md, warm-productivity-development-roadmap.md, all three app specs

---

**What changed:** Phase labels added to Cross-App Integration Map — every section now marked as Phase 1 (data layer) or Phase 12 (Cross-App UI).
**Why:** Integration Map was describing deferred UI features without indicating they were deferred, which would confuse an AI developer building Phase 1.
**Affected documents:** warm-productivity-cross-app-integration-map.md

---

## 2026-03-22

**What changed:** Added UI Polish Pass 1 as a dedicated milestone between Expense Tracker Phase 2 (Search & Filtering) and Phase 3 (Reconciliation). Updated build principle to include "polish at natural milestones" (3a). Phase 6 description updated to include a final full-app polish pass.
**Why:** Phases 1 and 2 are complete. Rather than accumulating visual debt across all 6 phases and fixing it at the end, a dedicated polish pass now — while the screen count is manageable — prevents compounding UI inconsistencies and ensures a solid visual foundation before reconciliation adds complexity.
**Affected documents:** 04_Development_Roadmap.md, 05_Expense_Tracker_App_Spec.md
