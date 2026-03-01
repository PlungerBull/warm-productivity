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
            // Shared models
            User.self,
            UserSettings.self,
            GlobalCurrency.self,
            ExchangeRate.self,
            EntityLink.self,
            UserSubscription.self,
            ActivityLog.self,
            // Expense models
            ExpenseBankAccount.self,
            ExpenseCategory.self,
            ExpenseHashtag.self,
            ExpenseReconciliation.self,
            ExpenseTransactionInbox.self,
            ExpenseTransaction.self,
            ExpenseBudget.self,
            ExpenseTransactionHashtag.self,
            TransactionShare.self,
            // Notes models
            NoteNotebook.self,
            NoteEntry.self,
            NoteHashtag.self,
            NoteEntryHashtag.self,
            // Todo models
            TodoCategory.self,
            TodoTask.self,
            TodoRecurrenceRule.self,
            TodoHashtag.self,
            TodoTaskHashtag.self,
            TodoCategoryMember.self,
            StreakCompletion.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: sharedStoreURL(),
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
