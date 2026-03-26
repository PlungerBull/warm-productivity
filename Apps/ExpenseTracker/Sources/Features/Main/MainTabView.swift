import SwiftUI
import SwiftData
import SharedUI

struct MainTabView: View {
    let userId: UUID
    let onSignOut: () async -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var showQuickEntry = false
    @State private var quickEntryHeight: CGFloat = 140

    var body: some View {
        TabView(selection: $selectedTab) {
            TransactionsTabView(userId: userId)
                .tabItem {
                    Label("Transactions", systemImage: "line.3.horizontal")
                }
                .tag(0)

            SettingsView(
                viewModel: SettingsViewModel(
                    userSettingsRepository: UserSettingsRepository(modelContext: modelContext),
                    userRepository: UserRepository(modelContext: modelContext),
                    currencyRepository: CurrencyRepository(modelContext: modelContext),
                    userId: userId
                ),
                onSignOut: onSignOut
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(1)
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab != 1 {
                FABButton {
                    showQuickEntry = true
                }
                .padding(.trailing, WPSpacing.lg)
                .padding(.bottom, WPSize.fabBottomOffset)
            }
        }
        .sheet(isPresented: $showQuickEntry) {
            QuickEntryView(
                viewModel: makeQuickEntryViewModel(),
                onDismiss: { showQuickEntry = false },
                sheetHeight: $quickEntryHeight
            )
            .presentationDetents([.height(quickEntryHeight)])
            .presentationDragIndicator(.hidden)
            .presentationSizing(.page)
        }
    }

    private func makeQuickEntryViewModel() -> QuickEntryViewModel {
        QuickEntryViewModel(
            transactionRepository: TransactionRepository(modelContext: modelContext),
            inboxRepository: InboxRepository(modelContext: modelContext),
            categoryRepository: CategoryRepository(modelContext: modelContext),
            bankAccountRepository: BankAccountRepository(modelContext: modelContext),
            hashtagRepository: HashtagRepository(modelContext: modelContext),
            transactionHashtagRepository: TransactionHashtagRepository(modelContext: modelContext),
            exchangeRateRepository: ExchangeRateRepository(modelContext: modelContext),
            noteEntryRepository: NoteEntryRepository(modelContext: modelContext),
            entityLinkRepository: EntityLinkRepository(modelContext: modelContext),
            userSettingsRepository: UserSettingsRepository(modelContext: modelContext),
            userId: userId
        )
    }
}
