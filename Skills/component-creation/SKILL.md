# Skill: Component Creation

**Use when:** Creating a new SwiftUI view, screen, ViewModel, or Repository — or modifying an existing one.

**Load before using:** `CLAUDE.md` (naming conventions, architecture pattern), `warm-productivity-vision-and-philosophy.md` (design principles).

---

## Architecture — MVVM + Repository

Every screen follows this exact three-layer structure. No exceptions.

```
SomeView.swift          ← SwiftUI view, observes ViewModel, zero business logic
SomeViewModel.swift     ← @Observable class, owns UI state, calls Repository
SomeRepository.swift    ← pure Swift class, reads/writes SwiftData, owns query logic
```

### Rules

| Layer | Can import | Cannot import | Responsibility |
|---|---|---|---|
| View | SwiftUI, SharedUI, ViewModel | Repository, SwiftData directly | Layout, user interaction, observe ViewModel state |
| ViewModel | Foundation, SharedModels, Repository | SwiftUI | UI state, validation, orchestrate Repository calls |
| Repository | Foundation, SwiftData, SharedModels | SwiftUI, ViewModels | CRUD operations, queries, sync queue management |

**Views never talk to Repositories directly.**
**Repositories never import SwiftUI.**

---

## File Organization

### App-Specific Screens

```
Apps/ExpenseTracker/Sources/
  Features/
    Transactions/
      TransactionListView.swift
      TransactionListViewModel.swift
      TransactionDetailView.swift
      TransactionDetailViewModel.swift
    Inbox/
      InboxListView.swift
      InboxListViewModel.swift
    Settings/
      SettingsView.swift
      SettingsViewModel.swift
  Repositories/
    TransactionRepository.swift
    BankAccountRepository.swift
    CategoryRepository.swift
```

### Shared Components

```
Packages/SharedUI/Sources/SharedUI/
  Components/
    FABButton.swift
    TransactionRow.swift
    EmptyStateView.swift
    LoadingView.swift
    ErrorBanner.swift
    TokenAutocompleteField.swift
  DesignSystem/
    Colors.swift
    Typography.swift
    Spacing.swift
    CornerRadius.swift
```

### Shared Models

```
Packages/SharedModels/Sources/SharedModels/
  ExpenseTransaction.swift
  ExpenseBankAccount.swift
  ExpenseCategory.swift
  NoteEntry.swift
  TodoTask.swift
  ...
```

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| Views | PascalCase + `View` suffix | `TransactionListView` |
| ViewModels | PascalCase + `ViewModel` suffix | `TransactionListViewModel` |
| Repositories | PascalCase + `Repository` suffix | `TransactionRepository` |
| SwiftData models | PascalCase, domain name | `ExpenseTransaction`, `NoteEntry` |
| Properties | camelCase | `amountCents`, `isCompleted` |
| Functions | camelCase, verb-first | `fetchTransactions()`, `deleteNote(id:)` |
| Files | Match the type name | `TransactionListView.swift` |
| Enum cases | camelCase | `.income`, `.expense`, `.draft` |

---

## View Template

```swift
import SwiftUI
import SharedUI

struct TransactionListView: View {
    @State private var viewModel: TransactionListViewModel

    init(repository: TransactionRepository) {
        _viewModel = State(initialValue: TransactionListViewModel(repository: repository))
    }

    var body: some View {
        // Layout only — no business logic
        // Use SharedUI components (Colors, Typography, Spacing)
        // Observe viewModel properties for state
    }
}
```

**Key rules for Views:**
- No `if/else` business logic — only layout conditionals (showing/hiding UI based on ViewModel state)
- No direct data fetching or mutation — delegate to ViewModel
- No hardcoded colors, fonts, or spacing — use SharedUI design tokens
- Use `@State private var viewModel` for the ViewModel binding
- Pass Repository via init, not as an environment object

---

## ViewModel Template

```swift
import Foundation
import SharedModels

@Observable
final class TransactionListViewModel {
    private let repository: TransactionRepository

    // UI State
    var transactions: [ExpenseTransaction] = []
    var isLoading = false
    var errorMessage: String?

    init(repository: TransactionRepository) {
        self.repository = repository
    }

    func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            transactions = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTransaction(_ id: UUID) async {
        do {
            try await repository.softDelete(id)
            transactions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

**Key rules for ViewModels:**
- Use `@Observable` (not `ObservableObject` — Swift 5.9+ Observation framework)
- Own all UI state (loading, error, data arrays, form fields)
- Perform validation before calling Repository
- Never import SwiftUI
- Call Repository methods, never access SwiftData directly

---

## Repository Template

```swift
import Foundation
import SwiftData
import SharedModels

final class TransactionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [ExpenseTransaction] {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByAccount(_ accountId: UUID) throws -> [ExpenseTransaction] {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate {
                $0.accountId == accountId && $0.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func create(_ transaction: ExpenseTransaction) throws {
        modelContext.insert(transaction)
        try modelContext.save()
    }

    func softDelete(_ id: UUID) throws {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate { $0.id == id }
        )
        guard let transaction = try modelContext.fetch(descriptor).first else { return }
        transaction.deletedAt = Date()
        try modelContext.save()
    }
}
```

**Key rules for Repositories:**
- Never import SwiftUI
- All reads filter by `deletedAt == nil` unless explicitly querying tombstones
- All deletes set `deletedAt`, never hard-delete
- Use SwiftData `FetchDescriptor` with `#Predicate`
- Accept `ModelContext` via init

---

## Design System — SharedUI

**No app may define its own colors, fonts, or spacing constants.** All visual constants come from `Packages/SharedUI/`.

### Color Palette

```swift
// Colors.swift — use throughout all views
extension Color {
    static let wpPrimary = ...
    static let wpSecondary = ...
    static let wpBackground = ...
    static let wpSurface = ...
    static let wpError = ...
    static let wpSuccess = ...
    // Light and dark variants handled via asset catalog or adaptive colors
}
```

### Typography Scale

Uses SF Pro (system font). Define as ViewModifiers or font extensions:

```swift
// Typography.swift
extension Font {
    static let wpTitle = Font.system(.title, design: .default)
    static let wpHeadline = Font.system(.headline, design: .default)
    static let wpBody = Font.system(.body, design: .default)
    static let wpCaption = Font.system(.caption, design: .default)
}
```

### Spacing System (4pt Grid)

```swift
// Spacing.swift
enum WPSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

### Corner Radius Tokens

```swift
// CornerRadius.swift
enum WPCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
}
```

---

## Shared Components

These live in `Packages/SharedUI/` and are used across all three apps.

| Component | Purpose |
|---|---|
| `FABButton` | Floating action button for quick entry, visible on all tabs except Settings |
| `TransactionRow` | Standard row layout for transaction lists (title, amount, date, category) |
| `EmptyStateView` | Centered message with optional icon for empty lists |
| `LoadingView` | Standard loading indicator |
| `ErrorBanner` | Non-intrusive error display |
| `TokenAutocompleteField` | Reusable token-based autocomplete for @category, $account, /person, #hashtag |

### TokenAutocompleteField

The shared autocomplete component. The caller provides the token type and a data source closure — the component handles display and selection.

```swift
TokenAutocompleteField(
    tokenType: .category,      // determines prefix symbol: @, $, /, #
    dataSource: { query in
        // Return filtered results matching the query
        categories.filter { $0.name.lowercased().hasPrefix(query.lowercased()) }
    },
    onSelect: { selected in
        // Handle confirmed selection
        viewModel.selectedCategory = selected
    },
    onCreate: { newName in
        // Handle "Create '[typed text]'" option
        viewModel.createCategory(name: newName)
    }
)
```

Behaviors:
- Real-time dropdown filtered by prefix match as user types
- Enter or tap confirms selection
- Escape or tap-outside dismisses
- "Create '[typed text]'" option when no matches exist

---

## Navigation Patterns

Follow these based on the flow type:

| Pattern | When to use | SwiftUI component |
|---|---|---|
| Linear flow | Step-by-step navigation (detail → sub-detail) | `NavigationStack` |
| Master-detail | Sidebar + content (e.g., Transactions tab) | `NavigationSplitView` |
| Tab-based root | App root with multiple sections | `TabView` |

Document the choice and reasoning when first implementing a navigation pattern in the Emerging Conventions section of CLAUDE.md.

---

## Common UI Patterns

### Bottom Sheet (Transaction Detail Modal)

Half-screen bottom sheet for item details. Use `.sheet` or `.presentationDetents([.medium, .large])`.

### Swipe to Delete

Standard iOS swipe gesture. Always soft-delete (set `deletedAt`).

### Context Menu (Long-Press)

On sidebar rows. Standard options: Rename, Change Color, Delete/Archive.

### Drag to Reorder

Section edit mode with drag handles. Persist to `sort_order`.

### Section Headers with `+` Button

Every sidebar section that can receive new items has a `+` on the header row.

---

## Pre-Creation Checklist

Before creating a new component:

- [ ] Does a similar component already exist in SharedUI? Reuse it.
- [ ] Is this component used by two or more apps? If yes, it goes in `Packages/SharedUI/`. If only one app, keep it app-specific.
- [ ] Does it follow the View → ViewModel → Repository layering?
- [ ] Are all visual constants coming from SharedUI (Colors, Typography, Spacing, CornerRadius)?
- [ ] File names match type names?
- [ ] Naming follows conventions (View suffix, ViewModel suffix, Repository suffix)?
- [ ] No business logic in the View?
- [ ] No SwiftUI imports in ViewModel or Repository?
- [ ] All data mutations go through soft-delete, never hard-delete?

## Post-Creation Checklist

After creating a component:

- [ ] View observes ViewModel via `@State private var viewModel`
- [ ] ViewModel uses `@Observable`, not `ObservableObject`
- [ ] Repository reads filter by `deletedAt == nil`
- [ ] Repository writes use `modelContext.save()`
- [ ] No hardcoded colors, fonts, or spacing values
- [ ] Empty states handled with `EmptyStateView`
- [ ] Loading states handled with `LoadingView`
- [ ] Error states surface via `ErrorBanner` or `errorMessage`
- [ ] Accessibility labels on interactive elements
