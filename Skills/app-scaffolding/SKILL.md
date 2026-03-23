# Skill: App Scaffolding

**Use when:** Creating a new Xcode project for one of the three apps (Expense Tracker, Notes, To-Do), adding it to the monorepo, wiring up shared packages, or spinning up the shared package infrastructure itself.

**Load before using:** `CLAUDE.md` (project structure, naming conventions, architecture pattern), `warm-productivity-system-architecture.md` (tech stack, App Group, auth, SwiftData).

---

## Pre-Flight Checklist

Before scaffolding, answer these questions:

1. **Which app are you scaffolding?** Expense Tracker, Notes, or To-Do. The app name determines the directory under `Apps/` and the Xcode project name.
2. **Do the shared packages exist yet?** If this is the first app, you must scaffold the `Packages/` infrastructure first (see Shared Packages below). If packages already exist, the new app imports them.
3. **Is the database schema deployed?** The schema-first principle requires all migrations to be applied before any app code is written. Confirm the Supabase schema is live.
4. **Do you have Supabase credentials?** You need the project URL and anon key for both testing and production environments.

---

## Monorepo Layout

All three apps and shared packages live in a single repository. The final structure:

```
warm-productivity/
├── Apps/
│   ├── ExpenseTracker/
│   │   ├── ExpenseTracker.xcodeproj
│   │   ├── Sources/
│   │   │   ├── App/
│   │   │   │   ├── ExpenseTrackerApp.swift
│   │   │   │   └── ContentView.swift
│   │   │   ├── Features/
│   │   │   │   └── (feature modules added per phase)
│   │   │   └── Repositories/
│   │   │       └── (repositories added per phase)
│   │   ├── Resources/
│   │   │   └── Assets.xcassets
│   │   └── ExpenseTracker.entitlements
│   ├── Notes/
│   │   ├── Notes.xcodeproj
│   │   ├── Sources/
│   │   │   ├── App/
│   │   │   ├── Features/
│   │   │   └── Repositories/
│   │   ├── Resources/
│   │   └── Notes.entitlements
│   └── ToDo/
│       ├── ToDo.xcodeproj
│       ├── Sources/
│       │   ├── App/
│       │   ├── Features/
│       │   └── Repositories/
│       ├── Resources/
│       └── ToDo.entitlements
├── Packages/
│   ├── SharedModels/
│   ├── RecurrenceEngine/
│   ├── SyncEngine/
│   ├── SupabaseClient/
│   ├── SharedUI/
│   └── SharedUtilities/
├── Configuration/
│   ├── Testing.xcconfig
│   └── Production.xcconfig
└── ...
```

**Dependency direction is strictly one-way:** apps depend on `Packages/`, packages never import from apps.

---

## Step 1: Scaffold Shared Packages

If this is the first app being scaffolded, create all six shared packages first. Each is a Swift Package Manager local package.

### Package.swift Template

Every package follows this structure:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PackageName",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "PackageName",
            targets: ["PackageName"]
        )
    ],
    dependencies: [
        // External or local package dependencies
    ],
    targets: [
        .target(
            name: "PackageName",
            dependencies: []
        ),
        .testTarget(
            name: "PackageNameTests",
            dependencies: ["PackageName"]
        )
    ]
)
```

### SharedModels

SwiftData entities shared across all three apps. This is the local mirror of the Supabase schema.

**Location:** `Packages/SharedModels/`

```
SharedModels/
├── Package.swift
├── Sources/
│   └── SharedModels/
│       ├── Expense/
│       │   ├── ExpenseTransaction.swift
│       │   ├── ExpenseBankAccount.swift
│       │   ├── ExpenseCategory.swift
│       │   ├── ExpenseTransactionInbox.swift
│       │   ├── ExpenseReconciliation.swift
│       │   ├── ExpenseBudget.swift
│       │   ├── ExpenseHashtag.swift
│       │   ├── ExpenseTransactionHashtag.swift
│       │   └── TransactionShare.swift
│       ├── Notes/
│       │   ├── NoteEntry.swift
│       │   ├── NoteNotebook.swift
│       │   ├── NoteHashtag.swift
│       │   └── NoteEntryHashtag.swift
│       ├── Todo/
│       │   ├── TodoTask.swift
│       │   ├── TodoCategory.swift
│       │   ├── TodoRecurrenceRule.swift
│       │   ├── TodoHashtag.swift
│       │   ├── TodoTaskHashtag.swift
│       │   ├── TodoCategoryMember.swift
│       │   └── StreakCompletion.swift
│       ├── Shared/
│       │   ├── User.swift
│       │   ├── UserSettings.swift
│       │   ├── GlobalCurrency.swift
│       │   ├── ExchangeRate.swift
│       │   ├── EntityLink.swift
│       │   ├── UserSubscription.swift
│       │   └── ActivityLog.swift
│       └── Enums/
│           └── SharedEnums.swift
└── Tests/
    └── SharedModelsTests/
```

**Dependencies:** SwiftData (system framework — no SPM dependency needed).

**Key rules:**
- Every `@Model` class maps 1:1 to a Supabase table
- Property names use camelCase, mapped to snake_case via `CodingKeys`
- Use `Int64` for `BIGINT` (cents), `Int` for `INTEGER` (version, sort_order)
- Use `Date` for `TIMESTAMPTZ`
- Use `UUID` for UUID columns
- Use Swift `enum` (with `String` raw values) for PostgreSQL enums
- Every mutable model includes: `createdAt`, `updatedAt`, `version`, `deletedAt`, `syncedAt`

### SupabaseClient

Supabase SDK configuration, auth helpers, and API layer.

**Location:** `Packages/SupabaseClient/`

```
SupabaseClient/
├── Package.swift
├── Sources/
│   └── SupabaseClient/
│       ├── SupabaseManager.swift
│       └── KeychainStorage.swift
└── Tests/
    └── SupabaseClientTests/
```

**External dependency:** Supabase Swift SDK.

```swift
// In Package.swift dependencies:
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
],
targets: [
    .target(
        name: "SupabaseClient",
        dependencies: [
            .product(name: "Supabase", package: "supabase-swift")
        ]
    )
]
```

**SupabaseManager** is the singleton entry point. It reads credentials from the xcconfig-injected `Info.plist` values (see Step 3) and configures the shared Keychain access group:

```swift
import Supabase
import Foundation

public final class SupabaseManager {
    public static let shared = SupabaseManager()

    public let client: SupabaseClient

    private init() {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String
        else {
            fatalError("Missing Supabase configuration in Info.plist")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: AuthClientOptions(
                    storage: KeychainLocalStorage(
                        accessGroup: "group.com.warmproductivity.shared"
                    )
                )
            )
        )
    }
}
```

### SyncEngine

Delta sync logic, conflict resolution, and queue management.

**Location:** `Packages/SyncEngine/`

**Dependencies:** SharedModels, SupabaseClient.

This package is scaffolded with placeholder files. Full implementation comes later (per the sync-engine skill when it's built). Initial scaffold:

```
SyncEngine/
├── Package.swift
├── Sources/
│   └── SyncEngine/
│       └── SyncEngine.swift    ← placeholder
└── Tests/
    └── SyncEngineTests/
```

### SharedUI

Design system and shared SwiftUI components.

**Location:** `Packages/SharedUI/`

```
SharedUI/
├── Package.swift
├── Sources/
│   └── SharedUI/
│       ├── DesignSystem/
│       │   ├── Colors.swift
│       │   ├── Typography.swift
│       │   ├── Spacing.swift
│       │   └── CornerRadius.swift
│       └── Components/
│           ├── FABButton.swift
│           ├── TransactionRow.swift
│           ├── EmptyStateView.swift
│           ├── LoadingView.swift
│           ├── ErrorBanner.swift
│           └── TokenAutocompleteField.swift
└── Tests/
    └── SharedUITests/
```

**Dependencies:** None (SwiftUI is a system framework).

**No app may define its own colors, fonts, or spacing constants.** See the component-creation skill for design token values.

### SharedUtilities

Common helpers, extensions, and formatters.

**Location:** `Packages/SharedUtilities/`

```
SharedUtilities/
├── Package.swift
├── Sources/
│   └── SharedUtilities/
│       ├── CommandParser.swift
│       └── Extensions/
└── Tests/
    └── SharedUtilitiesTests/
```

**Dependencies:** None.

`CommandParser` is a pure Swift struct that takes a raw FAB/quick-add string and returns a typed `ParsedCommand` struct. No UI, no SwiftData imports.

### RecurrenceEngine

Shared recurrence logic for both Expense Tracker and To-Do.

**Location:** `Packages/RecurrenceEngine/`

```
RecurrenceEngine/
├── Package.swift
├── Sources/
│   └── RecurrenceEngine/
│       └── RecurrenceEngine.swift    ← placeholder
└── Tests/
    └── RecurrenceEngineTests/
```

**Dependencies:** None. Pure Swift, no UI, no SwiftData.

Scaffolded with a placeholder. Full implementation comes during Expense Tracker Phase 5.

---

## Step 2: Create the Xcode Project

Each app is a standalone Xcode project under `Apps/`.

### Project Creation Settings

| Setting | Value |
|---|---|
| Template | iOS App |
| Interface | SwiftUI |
| Language | Swift |
| Storage | SwiftData |
| Testing System | Swift Testing |
| Minimum deployment target | iOS 26.0 |
| Bundle identifier | `com.warmproductivity.{appname}` |

Bundle identifiers:
- Expense Tracker: `com.warmproductivity.expensetracker`
- Notes: `com.warmproductivity.notes`
- To-Do: `com.warmproductivity.todo`

### App Entry Point Template

```swift
import SwiftUI
import SwiftData
import SharedModels
import SharedUI
import SupabaseClient

@main
struct ExpenseTrackerApp: App {
    let modelContainer: ModelContainer

    init() {
        modelContainer = Self.createModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }

    static func createModelContainer() -> ModelContainer {
        let schema = Schema([
            // All SwiftData models from SharedModels
            ExpenseTransaction.self,
            ExpenseBankAccount.self,
            ExpenseCategory.self,
            ExpenseTransactionInbox.self,
            ExpenseReconciliation.self,
            ExpenseBudget.self,
            ExpenseHashtag.self,
            ExpenseTransactionHashtag.self,
            TransactionShare.self,
            NoteEntry.self,
            NoteNotebook.self,
            NoteHashtag.self,
            NoteEntryHashtag.self,
            TodoTask.self,
            TodoCategory.self,
            TodoRecurrenceRule.self,
            TodoHashtag.self,
            TodoTaskHashtag.self,
            TodoCategoryMember.self,
            StreakCompletion.self,
            User.self,
            UserSettings.self,
            GlobalCurrency.self,
            ExchangeRate.self,
            EntityLink.self,
            UserSubscription.self,
            ActivityLog.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: Self.sharedStoreURL(),
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Returns the SwiftData store URL inside the shared App Group container.
    static func sharedStoreURL() -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.warmproductivity.shared"
        ) else {
            fatalError("App Group container not available")
        }
        return containerURL.appendingPathComponent("WarmProductivity.store")
    }
}
```

**Critical:** All three apps use the **same schema with all 27 models** and the **same store URL**. This is what makes cross-app data access instant — one shared SQLite database on disk.

**Critical:** `cloudKitDatabase: .none` — we use Supabase for sync, not CloudKit.

---

## Step 3: Configuration Files (.xcconfig)

Use `.xcconfig` files to manage Supabase credentials per environment. **Never hardcode credentials in source files.**

**Location:** `Configuration/` at the repository root (shared across all apps).

### Testing.xcconfig

```
// Configuration/Testing.xcconfig
// Supabase testing project credentials

SUPABASE_URL = https://your-test-project.supabase.co
SUPABASE_ANON_KEY = your-test-anon-key
```

### Production.xcconfig

```
// Configuration/Production.xcconfig
// Supabase production project credentials

SUPABASE_URL = https://your-prod-project.supabase.co
SUPABASE_ANON_KEY = your-prod-anon-key
```

### Wiring xcconfig to Info.plist

In each app's `Info.plist`, add these keys so `SupabaseManager` can read them at runtime:

```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

### Xcode Build Configuration Mapping

In each app's Xcode project:

| Build Configuration | xcconfig File |
|---|---|
| Debug | `Configuration/Testing.xcconfig` |
| Release | `Configuration/Production.xcconfig` |

Set via: Project → Info → Configurations → set the "Based on Configuration File" for each configuration.

### .gitignore

**Add the xcconfig files to `.gitignore`** to prevent credentials from being committed:

```
# Supabase credentials
Configuration/Testing.xcconfig
Configuration/Production.xcconfig
```

Provide a `Configuration/Example.xcconfig` as a template for other developers:

```
// Configuration/Example.xcconfig
// Copy this file to Testing.xcconfig and Production.xcconfig
// and fill in your Supabase credentials.

SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
```

---

## Step 4: App Group Entitlement

All three apps share a single App Group for local data access (SwiftData store) and auth session sharing (Keychain).

### Entitlement File

Each app has its own `.entitlements` file with the same App Group:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.warmproductivity.shared</string>
    </array>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)group.com.warmproductivity.shared</string>
    </array>
</dict>
</plist>
```

### What the App Group Provides

| Shared Resource | Where It Lives | Used By |
|---|---|---|
| SwiftData store | `group.com.warmproductivity.shared/WarmProductivity.store` | All three apps (instant cross-app data) |
| Supabase auth session | Keychain group `group.com.warmproductivity.shared` | All three apps (sign in once, authenticated everywhere) |
| User's display name | `UserDefaults(suiteName: "group.com.warmproductivity.shared")` | Saved during Sign in with Apple flow (see auth caveat) |

### Apple Developer Portal Setup

Before the entitlement works, register the App Group in the Apple Developer Portal:

1. Go to Certificates, Identifiers & Profiles → Identifiers → App Groups
2. Register: `group.com.warmproductivity.shared`
3. Add the App Group to each app's App ID under Capabilities

---

## Step 5: Add Supabase Swift SDK

The Supabase Swift SDK is the only external dependency. It's added to the `SupabaseClient` package, which the apps import transitively.

### Adding via SPM

In the `SupabaseClient` package's `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
]
```

This pulls in all Supabase modules: Auth, Database (PostgREST), Realtime, Storage, and Functions.

### What Each App Imports

Apps import `SupabaseClient` (the local package), not the Supabase SDK directly. This centralizes SDK configuration in one place.

```swift
// In an app file
import SupabaseClient

// Access the client
let client = SupabaseManager.shared.client
```

---

## Step 6: SwiftData Container Setup

### Shared Store — The Key Design Decision

All three apps point their `ModelContainer` at the same file inside the shared App Group container. This means data written by one app is immediately readable by the others — no sync, no network round-trip.

```swift
static func sharedStoreURL() -> URL {
    guard let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.warmproductivity.shared"
    ) else {
        fatalError("App Group container not available")
    }
    return containerURL.appendingPathComponent("WarmProductivity.store")
}
```

### Full Schema — All 27 Models

Every app registers **all** SwiftData models, not just its own. This is required because:

1. The shared store contains all data — if an app doesn't know about a model, SwiftData can't read/write it
2. Cross-app features (entity_links, activity_log, Universal Description Model) require access to other apps' models
3. SwiftData uses the full schema for lightweight migration — omitting a model could cause data loss

### ModelContainer Lifecycle

- Created once in the `App.init()` method
- Injected via `.modelContainer()` scene modifier
- Views access it via `@Environment(\.modelContext)`
- Repositories receive `ModelContext` via their initializer (dependency injection, not environment)

### Migration Strategy

SwiftData handles lightweight migrations automatically:
- Adding new properties to `@Model` classes: automatic
- Adding new `@Model` classes: automatic
- **Never rename or remove properties** — deprecate them by keeping the field and stopping writes to it

For destructive changes (rare), use `SchemaMigrationPlan`:

```swift
enum WarmProductivityMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }
    static var stages: [MigrationStage] {
        []
    }
}
```

---

## Step 7: Wire Local Packages to the Xcode Project

Each app's Xcode project adds the local packages as dependencies.

### Adding Local Packages

In Xcode:
1. File → Add Package Dependencies
2. Click "Add Local..." and select each package directory under `Packages/`
3. Add the package's library product to the app target under "Frameworks, Libraries, and Embedded Content"

### App → Package Dependency Map

Every app imports these packages:

| Package | Why |
|---|---|
| SharedModels | SwiftData entities for the shared store |
| SupabaseClient | Supabase SDK access (auth, API, storage) |
| SyncEngine | Background sync (placeholder initially) |
| SharedUI | Design system and shared components |
| SharedUtilities | Helpers, formatters, CommandParser |
| RecurrenceEngine | Recurrence logic (placeholder initially, used in Phase 5+) |

### Inter-Package Dependencies

```
SharedModels       → (none)
SharedUtilities    → (none)
RecurrenceEngine   → (none)
SharedUI           → (none)
SupabaseClient     → supabase-swift (external)
SyncEngine         → SharedModels, SupabaseClient
```

Apps depend on all six packages. Packages never depend on apps.

---

## Scaffolding Checklist — New App

When scaffolding a new app, complete every item:

- [ ] Xcode project created under `Apps/{AppName}/`
- [ ] Bundle identifier set: `com.warmproductivity.{appname}`
- [ ] Deployment target: iOS 26.0
- [ ] App entry point created with `ModelContainer` setup
- [ ] `sharedStoreURL()` points to App Group container
- [ ] All 27 SwiftData models registered in schema
- [ ] `cloudKitDatabase: .none` on ModelConfiguration
- [ ] `.entitlements` file with `group.com.warmproductivity.shared` App Group
- [ ] `.entitlements` file with Keychain access group
- [ ] `Info.plist` includes `SUPABASE_URL` and `SUPABASE_ANON_KEY` keys
- [ ] Debug configuration points to `Testing.xcconfig`
- [ ] Release configuration points to `Production.xcconfig`
- [ ] All six local packages added as dependencies
- [ ] `Sources/App/`, `Sources/Features/`, `Sources/Repositories/` directories created
- [ ] `Resources/Assets.xcassets` created
- [ ] App builds and launches (blank screen is fine — scaffolding complete)

## Scaffolding Checklist — First Time (Shared Infrastructure)

When this is the very first app (shared packages don't exist yet):

- [ ] `Configuration/` directory created with `Example.xcconfig`
- [ ] `Testing.xcconfig` and `Production.xcconfig` created (not committed)
- [ ] `.gitignore` updated to exclude xcconfig credential files
- [ ] `Packages/SharedModels/` scaffolded with Package.swift and directory structure
- [ ] `Packages/SupabaseClient/` scaffolded with Package.swift, SupabaseManager, supabase-swift dependency
- [ ] `Packages/SyncEngine/` scaffolded with Package.swift and placeholder
- [ ] `Packages/SharedUI/` scaffolded with Package.swift and design system directories
- [ ] `Packages/SharedUtilities/` scaffolded with Package.swift
- [ ] `Packages/RecurrenceEngine/` scaffolded with Package.swift and placeholder
- [ ] All packages resolve and build independently
- [ ] App builds with all packages linked

---

## Common Mistakes to Avoid

**1. Forgetting the App Group on a new app.** Without it, the app creates its own isolated SwiftData store and can't see data from the other apps. Always check the entitlements file.

**2. Registering only some models.** All three apps must register all 27 models. If Notes only registers note models, it can't read entity_links or write to activity_log.

**3. Hardcoding Supabase credentials.** Always use xcconfig → Info.plist → runtime lookup. Never put URLs or keys in Swift source files.

**4. Using CloudKit.** Set `cloudKitDatabase: .none`. We use Supabase for sync, not Apple's CloudKit.

**5. Creating the store outside the App Group.** The default SwiftData store location is app-private. Explicitly set the URL to the shared container.

**6. Importing the Supabase SDK directly in app code.** Always go through the `SupabaseClient` package. This centralizes configuration and makes it easy to swap or mock.

**7. Breaking the dependency direction.** Packages never import from apps. If you need app-specific logic, it stays in the app's `Sources/` directory.
