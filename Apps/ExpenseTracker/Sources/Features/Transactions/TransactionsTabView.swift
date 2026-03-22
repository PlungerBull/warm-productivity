import SwiftUI
import SwiftData
import SharedUI

struct TransactionsTabView: View {
    let userId: UUID
    @Environment(\.modelContext) private var modelContext

    @State private var selection: SidebarDestination?
    @State private var sidebarViewModel: TransactionsSidebarViewModel?
    @State private var listViewModel: TransactionListViewModel?
    @State private var showSearch: Bool = false

    var body: some View {
        NavigationSplitView {
            if let sidebarViewModel {
                TransactionsSidebarView(
                    viewModel: sidebarViewModel,
                    selection: $selection
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
            } else {
                LoadingView()
            }
        } detail: {
            if let listViewModel {
                TransactionListView(
                    destination: selection ?? .ledger,
                    viewModel: listViewModel,
                    detailViewModelFactory: { makeDetailViewModel() }
                )
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchView(
                viewModel: makeSearchViewModel(),
                detailViewModelFactory: { makeDetailViewModel() }
            )
        }
        .task {
            let bankAccountRepo = BankAccountRepository(modelContext: modelContext)
            let categoryRepo = CategoryRepository(modelContext: modelContext)
            let transactionRepo = TransactionRepository(modelContext: modelContext)
            let inboxRepo = InboxRepository(modelContext: modelContext)
            let settingsRepo = UserSettingsRepository(modelContext: modelContext)
            let hashtagRepo = HashtagRepository(modelContext: modelContext)
            let currencyRepo = CurrencyRepository(modelContext: modelContext)

            let sidebarVM = TransactionsSidebarViewModel(
                bankAccountRepository: bankAccountRepo,
                categoryRepository: categoryRepo,
                transactionRepository: transactionRepo,
                inboxRepository: inboxRepo,
                hashtagRepository: hashtagRepo,
                currencyRepository: currencyRepo,
                userSettingsRepository: settingsRepo,
                userId: userId
            )
            sidebarVM.loadSidebar()
            sidebarViewModel = sidebarVM

            let transactionHashtagRepo = TransactionHashtagRepository(modelContext: modelContext)

            let listVM = TransactionListViewModel(
                transactionRepository: transactionRepo,
                inboxRepository: inboxRepo,
                transactionHashtagRepository: transactionHashtagRepo,
                userSettingsRepository: settingsRepo,
                userId: userId
            )
            listViewModel = listVM
        }
    }

    private func makeDetailViewModel() -> TransactionDetailViewModel {
        TransactionDetailViewModel(
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

    private func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(
            transactionRepository: TransactionRepository(modelContext: modelContext),
            inboxRepository: InboxRepository(modelContext: modelContext),
            categoryRepository: CategoryRepository(modelContext: modelContext),
            bankAccountRepository: BankAccountRepository(modelContext: modelContext),
            hashtagRepository: HashtagRepository(modelContext: modelContext),
            transactionHashtagRepository: TransactionHashtagRepository(modelContext: modelContext),
            noteEntryRepository: NoteEntryRepository(modelContext: modelContext),
            entityLinkRepository: EntityLinkRepository(modelContext: modelContext),
            userSettingsRepository: UserSettingsRepository(modelContext: modelContext),
            userId: userId
        )
    }
}
