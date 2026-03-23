# UI Blueprints — Expense Tracker

Code-agnostic visual descriptions of every screen. Each blueprint describes exact layout, typography, spacing, colors, and logic so a developer can build it from scratch without seeing the HTML mockups.

---

## Global Design Tokens

### Colors (Light / Dark)
| Token | Light | Dark | Usage |
|---|---|---|---|
| Primary | #c2410c | #ea580c | Brick orange. Actions, active states, back links |
| Secondary | #b45309 | #d97706 | Warm amber. Highlights |
| Background | #ffffff | #1c1917 | Page/screen background |
| Surface | #fafaf9 | #292524 | Cards, elevated containers |
| Grouped BG | #f5f5f4 | #1c1917 | Scrollable area behind cards |
| Error/Expense | #dc2626 | #ef4444 | Expense amounts, destructive actions |
| Success/Income | #16a34a | #22c55e | Income amounts, ready states |
| Warning | #d97706 | #f59e0b | Missing fields, amber prompts |
| Hashtag | #4f6bed | #6b8af2 | # symbol badges, hashtag chips |
| Text Primary | #1c1917 | #fafaf9 | Titles, body text |
| Text Secondary | #78716c | #a8a29e | Labels, metadata |
| Text Tertiary | #a8a29e | #78716c | Placeholders, disabled text |
| Border | #e7e5e4 | #44403c | Dividers, card borders |
| On Primary | #ffffff | #ffffff | Text on primary-colored backgrounds |

### Typography (SF Pro)
| Token | Size | Weight | Usage |
|---|---|---|---|
| Large Title | 34pt | Bold (700) | Screen titles ("Transactions", "Ledger") |
| Title | 22pt | Semibold (600) | Section titles, detail hero title |
| Headline | 17pt | Semibold (600) | Emphasized text |
| Body | 17pt | Regular (400) | Primary content, row titles |
| Callout | 16pt | Regular (400) | Secondary content, descriptions |
| Caption | 12pt | Regular (400) | Metadata, section headers |
| Caption 2 | 11pt | Regular (400) | Badges, smallest text |
| Amount | 17pt | Medium (500) + monospacedDigit | Transaction amounts |
| Amount Large | 22pt | Semibold + monospacedDigit | Detail hero amount |

### Spacing (4pt grid)
| Token | Value |
|---|---|
| xxs | 4pt |
| xs | 8pt |
| sm | 12pt |
| md | 16pt |
| lg | 24pt |
| xl | 32pt |
| xxl | 48pt |

### Corner Radius
| Token | Value | Usage |
|---|---|---|
| Small | 8pt | Buttons, inputs, small cards |
| Medium | 12pt | Cards, grouped sections |
| Large | 16pt | Modals, sheets |

### Icons
All icons are SF Symbols (line style, not filled). Weight: regular or medium. Never use emoji.

---

## 1. Sign In Screen

### Container
A vertical stack filling the entire screen. Background: Background color. No tab bar visible.

### Layout (top to bottom)
1. **Status bar** — 54pt height. Time "9:41" left (15pt, semibold). Signal/wifi/battery icons right.
2. **Flexible spacer** — pushes content to vertical center
3. **App icon** — 72x72pt. A rounded rectangle outline (16pt corner radius) stroked in Primary color (2.5pt stroke, no fill). Inside: a stylized document/receipt line drawing also in Primary. Represents a financial document.
4. **App name** — "Warm Productivity" in Title size (22pt), Semibold, Text Primary. 24pt below icon.
5. **Subtitle** — "Expense Tracker" in Callout (16pt), Text Secondary. 6pt below app name.
6. **Flexible spacer** — pushes button to bottom
7. **Sign in with Apple button** — Full width (minus 32pt horizontal margins). Height ~50pt. Background: Text Primary (dark on light, light on dark). Text: Background color. 17pt Semibold. Apple logo (a small apple silhouette) + "Sign in with Apple". Corner radius: Medium (12pt). 20pt above privacy text.
8. **Privacy text** — "Your data stays private. We use Apple's authentication — no passwords stored." Caption size (12pt), Text Tertiary, centered, multi-line. 32pt bottom padding.

### Logic
- Button triggers Apple Sign In flow
- On success: new users go to Onboarding, returning users go to Transactions tab
- Error banner slides in from top if auth fails

---

## 2. Onboarding (Setup) Screen

### Container
A vertical stack filling the screen. Background: Background color. No tab bar.

### Layout (top to bottom)
1. **Status bar** — standard 54pt
2. **Top padding** — 32pt
3. **Title** — "Let's get you started." in Large Title (34pt), Bold, Text Primary. Left-aligned. Line break after "get" is natural word-wrap. Letter-spacing: -0.5pt.
4. **Subtitle** — "Two quick things and you're in." in Callout (16pt), Text Secondary. 8pt below title.
5. **Gap** — 48pt
6. **Currency label** — "Home Currency" in Caption (12pt), Medium weight, Text Secondary, uppercase, letter-spacing 0.5pt. Left-aligned.
7. **Currency picker row** — 6pt below label. Full width. Background: Grouped BG. Border: 1px Border color. Corner radius: Small (8pt). Padding: 12pt horizontal, 12pt vertical. Displays selected currency as "US Dollar (USD)" in Body (17pt), Text Primary. Right side: a small downward chevron (a "V" shape pointing down, 12x8pt, 1.5pt stroke, Text Tertiary).
8. **Gap** — 24pt
9. **Account label** — "First Bank Account" — same style as currency label
10. **Account text field** — 6pt below label. Same styling as currency row. Placeholder: "e.g., Chase Checking" in Text Tertiary.
11. **Flexible spacer**
12. **Get Started button** — Full width. Background: Primary. Text: On Primary (white), 17pt Semibold. Padding: 16pt vertical. Corner radius: Medium (12pt). 32pt bottom margin.

### Logic
- "Get Started" button disabled (40% opacity) until both currency is selected AND account name is non-empty
- On tap: creates user settings, creates bank account, creates 2 demo transactions, navigates to Transactions tab

---

## 3. Transactions Sidebar (Main Menu)

### Container
A vertical scroll view. Background: Grouped BG (#f5f5f4). No system navigation bar — title is custom.

### Layout (top to bottom)
1. **Title area** — 16pt horizontal padding. 8pt top padding. 24pt bottom padding.
   - "Transactions" in Large Title (34pt), Bold, Text Primary, letter-spacing -0.5pt.
   - A small magnifying glass icon (a circle with a diagonal line extending from bottom-right, ~16pt, Medium weight) in Text Secondary color, right-aligned. Tappable — opens search.

2. **Inbox/Ledger card** — A rounded card (Surface background, Medium corner radius 12pt). 16pt horizontal margin from screen edges.
   - **Inbox row**: 12pt vertical padding, 16pt horizontal. Left: a tray icon (an open-top box shape, 22pt, 1.5pt stroke) in Primary color. "Inbox" in Body (17pt), Text Primary. Spacer. If inbox count > 0: a capsule badge (Primary background, On Primary text, 11pt Semibold, min-width 20pt, height 20pt, 6pt horizontal padding, fully rounded). Right: a small right-pointing chevron (7x12pt, 1.5pt stroke, Text Tertiary).
   - **Divider** — 0.5pt line in Border color. Leading inset aligned with text (past the icon).
   - **Ledger row**: Same structure as Inbox but with a ledger/book icon (a rectangle with a horizontal line through the middle, representing a ledger, 22pt) in Primary color. "Ledger" text. No badge. Chevron right.
   - 12pt gap below this card.

3. **Bank Accounts section**:
   - **Section header** — 24pt top margin. 8pt bottom margin. 16pt horizontal padding. Left: "BANK ACCOUNTS" in Caption (12pt), Medium weight, Text Secondary, uppercase, letter-spacing 0.8pt. Right: "+" symbol in Primary color (18pt). Tappable — opens create account sheet.
   - **Rows card** — Surface background, Medium corner radius. 16pt horizontal margin. Each row:
     - **Symbol badge**: 28x28pt rounded square (6pt corner radius). Background: the account's color at 12% opacity. Centered text: "$" in the account's color, 14pt Bold.
     - 12pt gap after badge.
     - Account name: Body (17pt), Text Primary. Fills remaining space.
     - Balance amount: Amount font (17pt, Medium, monospacedDigit). Green (#16a34a) if positive, Red (#dc2626) if negative. Right-aligned.
     - Rows separated by 0.5pt Border-colored dividers, inset past the symbol badge (28pt + 12pt = 40pt from left).
     - Row padding: 8pt vertical, 16pt horizontal.

4. **Categories section** — Same structure as Bank Accounts.
   - Symbol badge uses "@" in the category's color.
   - Value shows monthly spend amount in Text Secondary (not colored).

5. **Hashtags section** — Same structure.
   - Symbol badge uses "#" in Hashtag blue (#4f6bed).
   - No value amount shown.

6. **Bottom spacer** — 120pt minimum to clear the FAB and tab bar.

### Overlay
- **FAB** — Floating action button. 56x56pt circle. Primary background. White "+" (28pt, light weight 300). Positioned 24pt from right edge, 100pt from bottom (above tab bar). Shadow: 0 4pt 16pt Primary at 30% opacity.

### Tab Bar
- Height: 83pt (includes 34pt home indicator padding). Surface background. 0.5pt Border top line.
- Two items centered with 80pt gap: "Transactions" (active, Primary color) and "Settings" (inactive, Text Tertiary).
- Each item: icon (24x24pt SVG line icon, 1.5pt stroke) + label (10pt) stacked vertically with 2pt gap.
- Transactions icon: three horizontal lines (a hamburger/list icon).
- Settings icon: a gear shape (circle with radiating spokes).

---

## 4. Ledger List (Flat)

### Container
A vertical stack. Background: Background (white). No system navigation bar (hidden).

### Header (fixed at top)
1. **Back link** — 16pt horizontal padding. 4pt top padding.
   - A small left-pointing chevron (13pt, Semibold) + "Transactions" (15pt) in Primary color. Tappable — pops back to sidebar.
2. **Title** — "Ledger" in Title (22pt), Semibold, Text Primary. 2pt below back link. 12pt bottom padding.

### Search bar (ledger only — not shown on inbox)
- 16pt horizontal margin. Background: Grouped BG. Corner radius: 8pt. Padding: 10pt horizontal, 8pt vertical.
- Left: magnifying glass icon (16pt, Text Tertiary). "Search transactions" placeholder in Body (15pt), Text Tertiary.

### Transaction rows (scrollable)
A flat vertical list with no date groupings or section headers. Each row:

- **Left border** — 3pt wide vertical strip touching the left edge of the screen. Color: the transaction's category color. This is the ONLY indicator of category — no text label.
- **Content area** — 13pt left padding (after the 3pt border). 16pt right padding. 12pt vertical padding.
  - **Title** — Body (17pt), Text Primary. Left-aligned. Single line, truncates with ellipsis if too long.
  - **Spacer** — minimum 8pt
  - **Account name** — Caption (12pt), Text Tertiary. Right of title, before amount. Shrinks before title truncates (layout priority -1). Single line.
  - **Amount** — Amount font (17pt, Medium, monospacedDigit). Expense: "-$67.32" in Error/Expense red. Income: "+$2,320.00" in Success/Income green. Right-aligned, never truncates (fixed size).
- **Divider** — 0.5pt Border color, 16pt leading inset.

### Logic
- Tap any row: opens Transaction Detail as a half-screen bottom sheet
- Swipe left on row: reveals red "Delete" action
- List sorted by date descending (newest first)

---

## 5. Inbox List (Flat)

### Container
Same structure as Ledger but with different header title and no search bar.

### Header
- Back link: same as Ledger
- Title: "Inbox" in Title (22pt)
- No search bar

### Inbox rows (scrollable)
Flat vertical list, no groupings. Each row:

- **Left border** — 3pt wide. Green (Success #16a34a) if the item is ready to promote (all required fields present: title, amount, date, account, category). **No border** (just 16pt left padding) if any required field is missing.
- **Content area** — same padding as ledger rows
  - **Title** — Body (17pt), Text Primary. "Untitled" in Text Tertiary + italic if title is the placeholder.
  - **Spacer**
  - **Amount** — Amount font, Text Primary (not colored — inbox items don't distinguish expense/income). Shows "$34.99" without sign. If no amount set: an em dash "—".
- **Divider** — 0.5pt Border, 16pt leading inset.

### Logic
- Green border = all required fields present AND date is today or past. Ready to promote.
- No border = one or more required fields missing. Missing fields are NOT shown inline — they're revealed in the detail sheet when the user taps the row.
- Tap row: opens Transaction Detail sheet
- Swipe left: delete

---

## 6. Quick Entry Panel

### Presentation
A half-screen bottom sheet. Presented over the current screen (sidebar or list). The content behind remains visible and interactive (not dimmed). Sheet dismisses by swiping down.

### Layout (top to bottom)

1. **Drag handle** — 36x4pt rounded pill (2pt corner radius), Border color, centered horizontally. 8pt top padding, 12pt bottom padding.

2. **Destination indicator** — Small text showing where the transaction will go:
   - If all required fields present: "Ledger" in Text Tertiary (11pt) with a small checkmark icon
   - If missing fields: "Inbox — needs category and account" in Warning amber (11pt) with a small tray icon. Lists the specific missing fields.

3. **Command input** — The hero element. A plain text field with NO border, NO background. Body font (17pt), Text Primary. Placeholder: "e.g. -45 Lunch @Food $BCP" in Text Tertiary. Tokens typed by the user render in their semantic colors inline: @category in Primary, $account in Success green, #hashtag in Hashtag blue.

4. **Description field** — Below input. Callout (16pt), Text Tertiary placeholder "Description". Plain text field, no border.

5. **Toolbar row** — Horizontal row of pill buttons + circular send button.
   - Each pill: 6pt corner radius. Padding: 5pt vertical, 10pt horizontal. 13pt Medium weight text. Contains an SF Symbol icon + a value label.
   - **Date pill**: Calendar icon (a square grid with lines for days) + "Today" / "Yesterday" / formatted date. Color: Success green when set. Background: Grouped BG.
   - **Category pill**: Tag icon (a price tag / label shape with a small circle) + category name. Color: Primary when set. When NOT set (required but missing): Warning amber text, background Warning at 8% opacity, 1pt dashed border in Warning at 35% opacity, label shows "Category".
   - **Account pill**: Building/columns icon (a classical building facade) + account name. Same selected/missing styling as category.
   - **"···" overflow** — 15pt, Text Tertiary. For extra options.
   - **Circular send button** — 34pt diameter circle. When active (command text not empty): Primary background, white arrow-up icon (16pt, 2.5pt stroke). When inactive: Text Tertiary at 40% opacity. Far right of toolbar, 8pt left margin.

### Logic
- Command text is parsed in real-time by CommandParser
- Toolbar pills update to reflect parsed values
- Missing required fields shown as amber dashed pills
- Send button submits: if all fields present → ledger, if missing fields → inbox
- Sheet dismisses after successful save

---

## 7. Transaction Detail (Bottom Sheet)

### Presentation
A half-screen bottom sheet (.medium detent, expandable to .large). Content behind visible but dimmed.

### Layout (top to bottom) — Content-first, NO form labels

1. **Drag handle** — 36x4pt, Border color, centered. 12pt top, 12pt bottom.

2. **Header row** — Horizontal layout, 16pt horizontal padding.
   - Left: Account name in Success green (13pt, Medium) + small right chevron (10pt, Text Tertiary). Tappable to change account. Preceded by a building/columns icon (13pt).
   - Right: Trash icon (a trash can outline, 16pt, Text Tertiary) + "···" ellipsis icon (16pt, Text Tertiary). 24pt gap between them.

3. **Date line** — 12pt below header. Calendar icon (13pt) + "Today, Mar 22" in Primary color (13pt). Tappable — opens date picker.

4. **Title** — Title size (22pt), Semibold, Text Primary. Plain editable text field, no border. Tappable to edit.

5. **Amount** — 28pt, Semibold, monospacedDigit. Expense: "-$67.32" in Expense red. Income: "+$2,320.00" in Income green. 4pt below title. Tappable to edit with +/- toggle.

6. **Description** — 16pt below amount. Callout (16pt). If content exists: Text Primary. If empty: "Add a description..." in Text Tertiary. Editable.

7. **Tags area** — 24pt below description. Horizontal wrapping layout of small chips:
   - Category chip: "@Groceries" — 12pt Medium, category color text, category color at 8% opacity background, 4pt corner radius, 10pt horizontal padding, 3pt vertical padding.
   - Hashtag chips: "#weekly" — same style but in Hashtag blue.
   - Tappable to edit.

8. **Flexible spacer**

9. **Promote button** (INBOX ONLY) — Full width Primary button with arrow-up icon + "Promote to Ledger". Only visible when all required fields are present (canPromote = true). 12pt corner radius, 16pt vertical padding, 17pt Semibold text.

10. **Bottom toolbar** — Thin top border (0.5pt, Border color). 12pt vertical padding, 24pt horizontal padding. Three SF Symbol icons in Text Tertiary (16pt):
    - Tag icon (a price tag shape) — opens category picker
    - Hash icon (the # character drawn as crossing lines) — opens hashtag picker
    - Paperclip icon (a curved clip shape) — opens attachment picker

### Logic
- All fields editable in-place (TextFields styled as plain text)
- Save triggers automatically on dismiss or via toolbar checkmark
- Delete via trash icon with confirmation alert
- Inbox items show "Promote to Ledger" when ready
- Exchange rate row shown only when account currency differs from home currency

---

## 8. Search Screen

### Presentation
Full-screen sheet.

### Layout

1. **Search bar** — 16pt horizontal padding, 8pt top padding.
   - Horizontal layout: Search pill (flex) + "Cancel" text button (Primary color, 17pt).
   - Search pill: Grouped BG background, fully rounded (capsule). 12pt horizontal padding, 8pt vertical. Magnifying glass icon (15pt, Text Tertiary) + TextField (Body 15pt, Text Primary). Clear button (X in circle, 14pt, Text Tertiary) appears when text is non-empty.
   - Auto-focuses on appear.

2. **Results** — Scrollable vertical list below search bar.
   - **Section headers**: "LEDGER (4 RESULTS)" — Caption (12pt), Semibold, Text Secondary, uppercase, letter-spacing 0.5pt. 16pt horizontal padding, 24pt top margin.
   - **Ledger result rows**: Two-line layout. Line 1: Title with matching substring highlighted (Primary color text on Primary at 12% opacity background). Amount right-aligned (expense red / income green). Line 2: "Mar 22" date + "@Dining" in category's Primary color, Caption (12pt), Text Tertiary.
   - **Inbox result rows**: Amber/green status dot (8pt circle) + title with highlight. Line 2: "Missing account, category" in Warning amber (Caption). Amount right-aligned, Text Primary.
   - Rows separated by 0.5pt Border dividers.

3. **Empty state — no query**: Centered. Magnifying glass icon (48pt, light weight, Text Tertiary). "Search Transactions" in Headline (17pt Semibold). Subtitle in Callout, Text Secondary.

4. **Empty state — no results**: Same centered layout. "No results" title. "Try a different search term or check your spelling." subtitle.

### Logic
- Results update on every keystroke
- Tap result: opens Transaction Detail sheet
- "Cancel" dismisses the search

---

## 9. Settings Screen

### Container
Scrollable vertical list. Background: Grouped BG.

### Layout

1. **Title** — "Settings" in Large Title (34pt), Bold. 16pt horizontal padding, 32pt top margin.

2. **Profile card** — Surface card, Medium corner radius. 16pt margin. 16pt padding.
   - Left: Avatar circle (48pt diameter, Primary background, white initials "JD" in 18pt Semibold).
   - Right of avatar (12pt gap): Name "John Doe" in Body Semibold. Email "john@icloud.com" in Caption, Text Secondary.

3. **General section** — "GENERAL" section header (Caption, Semibold, Secondary, uppercase, tracking). Card with rows:
   - "Home Currency" — Body left, "USD >" right in Text Secondary
   - "Default Account" — Body left, "Chase >" right
   - Rows separated by 0.5pt inset dividers.

4. **Display section** — Same structure.
   - "Appearance" — "System >" right

5. **Data section** — Same structure.
   - "Import CSV" — chevron right
   - "Export Data" — chevron right

6. **Sign Out** — Centered Error/red text, Body weight. In its own card.

7. **Footer** — "Warm Productivity v1.0.0" in Caption, Text Tertiary, centered. 24pt bottom margin.

---

## 10. Empty States

### First Launch Sidebar
Same sidebar layout but sections show helper text instead of rows:
- Bank Accounts card: "Tap + to add your first account" in Callout, Text Tertiary, centered, 16pt padding
- Categories card: "Tap + to create categories" — same style
- Hashtags card: "Hashtags appear as you use them" — same style

### Skeleton Loading (Ledger)
Same layout as Ledger but rows are replaced with shimmer placeholders:
- Animated gradient moving left-to-right (Grouped BG → Border → Grouped BG, 200% width, 1.5s ease-in-out infinite)
- Each row: a short rectangle (60% width, 14pt height, 4pt corner radius) + amount placeholder (60pt width) right-aligned
- 6-8 skeleton rows

### Search No Results
Centered vertical stack:
- Magnifying glass icon (48pt, light weight, Text Tertiary)
- "No results" in Headline (17pt Semibold), Text Primary
- "Try a different search term or check your spelling." in Callout, Text Secondary, centered

---

## 11. Error Banner

### Layout
- 8pt vertical margin, 16pt horizontal margin from screen edges
- Background: #fef2f2 (light) / Error at 10% opacity (dark)
- Border: 1px #fecaca (light) / Error at 20% opacity (dark)
- Corner radius: Small (8pt)
- Padding: 12pt vertical, 16pt horizontal
- Horizontal layout: Warning triangle icon (a triangle outline with "!" inside, 14pt) + message text (13pt, line-height 1.4, #991b1b light / #fca5a5 dark) + spacer + dismiss X button (14pt, Text Tertiary)

### Logic
- Slides in from top with animation
- Auto-dismisses after 5 seconds, or tap X to dismiss immediately
- Non-blocking — user can still interact with the app
- Example: "Sync paused — no internet connection. Your data is saved locally."
