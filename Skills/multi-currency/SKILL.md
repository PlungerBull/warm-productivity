# Skill: Multi-Currency

**Use when:** Handling multi-currency amounts, exchange rates, home currency conversion, currency display, or main_currency change recalculation.

**Load before using:** `warm-productivity-system-architecture.md` (Exchange Rates section), `warm-productivity-expense-tracker-app-spec.md` (currency-related flows).

---

## Core Model

### One Currency Per Bank Account

Each `expense_bank_accounts` row has exactly one `currency_code`. This is immutable after creation.

- A real-world card that handles PEN and USD becomes two accounts: `BCP PEN` and `BCP USD`.
- A person who shares expenses in both PEN and USD gets two virtual accounts (one per currency), auto-created when first tagged on an expense in each currency.
- The account's `currency_code` determines the currency of every transaction in it. No per-transaction currency override within an account.

### Two Amount Fields Per Transaction

```
amount_cents       BIGINT NOT NULL    -- original amount in account currency (immutable)
amount_home_cents  BIGINT             -- cached display value in user's main_currency (derived)
exchange_rate      NUMERIC NOT NULL DEFAULT 1.0  -- account currency → main_currency
```

**`amount_cents`** is the source of truth. It never changes regardless of display settings, main_currency changes, or exchange rate updates.

**`amount_home_cents`** = `amount_cents * exchange_rate`. It is a cached display convenience — always derivable. Recalculated when `main_currency` changes or when the user edits `exchange_rate`.

**`exchange_rate`** converts from the account's currency to the user's `main_currency`. It is 1.0 when the account currency matches `main_currency`.

---

## Exchange Rate Reference Table

### Structure

```sql
exchange_rates
  - base_currency    TEXT NOT NULL  -- always 'USD'
  - target_currency  TEXT NOT NULL  -- e.g., 'PEN', 'HKD'
  - rate             NUMERIC NOT NULL  -- 1 USD = [rate] target_currency
  - rate_date        DATE NOT NULL
  - UNIQUE (base_currency, target_currency, rate_date)
```

**Single-base approach:** All rates are expressed as `1 USD = X target_currency`. Only N-1 rows per day (one per non-USD currency). No user_id — this is a global reference table.

### Deriving Cross-Currency Rates

To convert between two non-USD currencies (e.g., PEN to HKD):

```
1. Look up USD→PEN rate for the date (e.g., 3.75)
2. Look up USD→HKD rate for the date (e.g., 7.82)
3. PEN→HKD = (1 / PEN_rate) * HKD_rate = (1/3.75) * 7.82 = 2.085
```

To convert any currency to USD:
```
X→USD = 1 / (USD→X rate)
```

To convert USD to any currency:
```
USD→X = USD→X rate (direct lookup)
```

### Fallback Rule

If no rate exists for a given date, use the most recent available rate for that currency pair. The app never fails to convert — it uses slightly stale data rather than showing an error.

```swift
// Repository pseudocode
func rate(for currency: String, on date: Date) -> Decimal {
    // 1. Try exact date
    // 2. Fallback: most recent rate before that date
    // 3. Fallback: most recent rate at all
    // Never return nil — always return a rate
}
```

### Phase 1 vs. Future

**Phase 1 (manual):** Exchange rates are manually populated. The user enters rates via the app or they're seeded directly. Sufficient for launch with PEN + USD.

**Future (automated):** A Supabase Edge Function on a daily cron schedule fetches rates from `api.frankfurter.app` (free, no API key, ECB-backed) and writes to `exchange_rates` with `base_currency = 'USD'`.

---

## Per-Transaction Exchange Rate

### Auto-Fill Logic

When a transaction is created and the account currency differs from `main_currency`:

1. Look up the rate from the reference table for the transaction's date
2. If the account currency is USD: `exchange_rate = 1 / (USD→main_currency rate)`... no, let me reclarify.

The `exchange_rate` field means: **account currency → main_currency**. To derive this:

| Account Currency | Main Currency | Derivation |
|---|---|---|
| USD | PEN | Direct: `USD→PEN rate` (e.g., 3.75 means 1 account unit = 3.75 main units)... |

Wait — let's be precise. The stored rate answers: "How many units of main_currency does 1 unit of account currency buy?"

| Account Currency | Main Currency | exchange_rate = |
|---|---|---|
| PEN | USD | `1 / (USD→PEN rate)` = `1/3.75` = `0.267` |
| USD | PEN | `USD→PEN rate` = `3.75` |
| PEN | HKD | `(1 / USD→PEN) * USD→HKD` = `(1/3.75) * 7.82` = `2.085` |
| USD | USD | `1.0` (same currency) |
| PEN | PEN | `1.0` (same currency) |

### User Override

The user can manually edit `exchange_rate` on any transaction because real-world rates vary by vendor (street exchange, bank, app). When the user edits:

1. `exchange_rate` updates to the user's value
2. `amount_home_cents` recalculates immediately: `amount_cents * new_exchange_rate`
3. The original `amount_cents` never changes

### Never Blocks Promotion

Exchange rate is never a required field that blocks inbox-to-ledger promotion. It auto-populates from the reference table. If no rate exists at all, it defaults to 1.0 and the user can override later.

---

## Recalculation on Main Currency Change

When the user changes `main_currency` in `user_settings`, an Edge Function recalculates every transaction's `exchange_rate` and `amount_home_cents`.

### Regular Expenses (no cross-currency transfer)

```
1. For each transaction:
   a. Look up the rate from exchange_rates for (account_currency → new_main_currency) on the transaction's date
   b. Set exchange_rate = derived rate
   c. Set amount_home_cents = amount_cents * exchange_rate
2. Any previous user override is LOST — the old rate was for the old currency pair
```

### Cross-Currency Transfers (special handling)

A cross-currency transfer is a transaction that has a `transfer_id` AND the linked transaction (same `transfer_id`) is on an account with a different `currency_code`.

**When main_currency matches one of the two legs:**

Use the **implied transfer rate** (derived from the two amounts) instead of the reference table rate. This ensures transfers net to zero on the dashboard.

Example: Transfer of 10 PEN → 3.40 USD. Main currency changes to USD.
- PEN leg: `exchange_rate = 3.40/10 = 0.34` (implied), `amount_home_cents = -10 * 0.34 = -3.40 USD`
- USD leg: `exchange_rate = 1.0`, `amount_home_cents = +3.40 USD`
- Net: zero. Correct — money was moved, not created or lost.

**When main_currency matches neither leg:**

Both legs recalculate from the reference table normally.

| Main currency matches... | PEN leg rate | USD leg rate |
|---|---|---|
| USD (matches USD leg) | Implied: `USD_amount / PEN_amount` | 1.0 |
| PEN (matches PEN leg) | 1.0 | Implied: `PEN_amount / USD_amount` |
| HKD (matches neither) | Reference table: PEN→HKD | Reference table: USD→HKD |

---

## Currency Display

### Formatting Rules

- **Always show the currency symbol** from `global_currencies.symbol` (e.g., `$`, `S/`)
- **Amount formatting:** Use the locale-appropriate thousands separator and decimal (e.g., `$1,234.50`, `S/3,050.00`)
- **Cents to display:** Divide by 100 for display. `3050` cents → `30.50`
- **Sign convention:** `-` prefix for expenses/outflows, `+` prefix for income/inflows

### Where Each Currency Appears

| Context | Currency used | Source |
|---|---|---|
| Transaction row (primary) | Account currency | `expense_bank_accounts.currency_code` |
| Transaction row (secondary, if different) | Main currency | `user_settings.main_currency` |
| Bank account sidebar balance | Main currency | `amount_home_cents` totals |
| People sidebar balance | Account currency (NOT converted) | `current_balance_cents` on person account |
| Category sidebar (monthly spend) | Main currency | `SUM(amount_home_cents)` for current month |
| Budget amounts | Main currency | `expense_budgets.amount_cents` |
| Budget vs. actual | Main currency | Budget amount vs. `SUM(amount_home_cents)` |

### Dual Currency Display

When a transaction's account currency differs from `main_currency`, show both:

```
-S/100.00          ← primary: account currency amount
≈ -$26.67          ← secondary: home currency equivalent
```

When they match, show only one amount.

---

## Budget Integration

Budget amounts (`expense_budgets.amount_cents`) are always in the user's `main_currency`.

**"Spent" calculation:** `SUM(amount_home_cents)` for transactions in that category within the current calendar month. Comparison is against `expense_budgets.amount_cents`.

**When main_currency changes:** Budget amounts stay as-is (they're abstract targets). The "spent" side recalculates because `amount_home_cents` is recalculated on all transactions.

---

## Implementation Checklist

When implementing a feature that touches currency:

- [ ] Use `BIGINT` cents for all monetary values, never floating point
- [ ] Store `amount_cents` in account currency (immutable)
- [ ] Derive `amount_home_cents` from `amount_cents * exchange_rate`
- [ ] Auto-fill `exchange_rate` from reference table on transaction creation
- [ ] Allow user to override `exchange_rate` per transaction
- [ ] Set `exchange_rate = 1.0` when account currency = main_currency
- [ ] Use fallback rule (most recent rate) when no rate exists for a date
- [ ] Derive cross-currency rates through USD (single-base approach)
- [ ] Handle cross-currency transfers with implied rates on main_currency change
- [ ] Show dual currency display when account currency differs from main_currency
- [ ] People sidebar balances show account currency, not main_currency
- [ ] All other sidebar/dashboard amounts show main_currency
- [ ] Budget amounts are in main_currency, compared against `SUM(amount_home_cents)`
