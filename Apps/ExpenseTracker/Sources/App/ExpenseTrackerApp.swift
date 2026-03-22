import SwiftUI
import SwiftData
import SharedModels
import SharedUI
import SharedUtilities
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

    /// Returns the SwiftData store URL inside the shared App Group container,
    /// falling back to the app's documents directory when the container is unavailable
    /// (e.g. simulator without a registered App Group).
    static func sharedStoreURL() -> URL {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) {
            return containerURL.appendingPathComponent("WarmProductivity.store")
        }
        return URL.documentsDirectory.appendingPathComponent("WarmProductivity.store")
    }
}
