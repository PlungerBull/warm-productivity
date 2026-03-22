import Foundation
import SharedModels
import SharedUtilities

struct DateGroup<T>: Identifiable {
    let id: Date
    let date: Date
    let items: [T]

    var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return CurrencyFormatter.formatDate(date)
    }
}

@MainActor
@Observable
final class TransactionListViewModel {
    private let transactionRepository: TransactionRepository
    private let inboxRepository: InboxRepository
    private let transactionHashtagRepository: TransactionHashtagRepository
    private let userSettingsRepository: UserSettingsRepository
    private let userId: UUID

    var ledgerItems: [ExpenseTransaction] = []
    var inboxItems: [ExpenseTransactionInbox] = []
    private(set) var currencyFormatter = CurrencyFormatter()

    // Detail modal state
    var selectedInboxItem: ExpenseTransactionInbox?
    var selectedLedgerItem: ExpenseTransaction?
    var showDetail: Bool = false

    // Delete confirmation
    var deleteConfirmationId: UUID?
    var deleteIsInbox: Bool = false
    var showDeleteConfirmation: Bool = false

    init(
        transactionRepository: TransactionRepository,
        inboxRepository: InboxRepository,
        transactionHashtagRepository: TransactionHashtagRepository,
        userSettingsRepository: UserSettingsRepository,
        userId: UUID
    ) {
        self.transactionRepository = transactionRepository
        self.inboxRepository = inboxRepository
        self.transactionHashtagRepository = transactionHashtagRepository
        self.userSettingsRepository = userSettingsRepository
        self.userId = userId
    }

    func load(destination: SidebarDestination) {
        do {
            if let settings = try userSettingsRepository.fetchSettings(userId: userId) {
                currencyFormatter = CurrencyFormatter(currencyCode: settings.mainCurrency)
            }

            switch destination {
            case .inbox:
                inboxItems = try inboxRepository.fetchAll(userId: userId)
                ledgerItems = []
            case .ledger:
                ledgerItems = try transactionRepository.fetchAll(userId: userId)
                inboxItems = []
            case .bankAccount(let id):
                ledgerItems = try transactionRepository.fetchByAccount(userId: userId, accountId: id)
                inboxItems = []
            case .category(let id):
                ledgerItems = try transactionRepository.fetchByCategory(userId: userId, categoryId: id)
                inboxItems = []
            case .hashtag(let id):
                let transactionIds = try transactionHashtagRepository.fetchTransactionIds(hashtagId: id)
                ledgerItems = try transactionRepository.fetchByIds(userId: userId, ids: transactionIds)
                inboxItems = []
            }
        } catch {
            ledgerItems = []
            inboxItems = []
        }
    }

    // MARK: - Date Grouped Data

    var ledgerDateGroups: [DateGroup<ExpenseTransaction>] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: ledgerItems) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.map { DateGroup(id: $0.key, date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var overdueInboxItems: [ExpenseTransactionInbox] {
        let today = Calendar.current.startOfDay(for: Date())
        return inboxItems.filter { item in
            guard let date = item.date else { return false }
            return date < today
        }
    }

    var currentInboxItems: [ExpenseTransactionInbox] {
        let today = Calendar.current.startOfDay(for: Date())
        return inboxItems.filter { item in
            guard let date = item.date else { return true } // no date = current
            return date >= today
        }
    }

    // MARK: - Selection

    func selectInboxItem(_ item: ExpenseTransactionInbox) {
        selectedInboxItem = item
        selectedLedgerItem = nil
        showDetail = true
    }

    func selectLedgerItem(_ item: ExpenseTransaction) {
        selectedLedgerItem = item
        selectedInboxItem = nil
        showDetail = true
    }

    func dismissDetail() {
        showDetail = false
        selectedInboxItem = nil
        selectedLedgerItem = nil
    }

    // MARK: - Delete

    func confirmDeleteInbox(id: UUID) {
        deleteConfirmationId = id
        deleteIsInbox = true
        showDeleteConfirmation = true
    }

    func confirmDeleteLedger(id: UUID) {
        deleteConfirmationId = id
        deleteIsInbox = false
        showDeleteConfirmation = true
    }

    func performDelete() {
        guard let id = deleteConfirmationId else { return }
        do {
            if deleteIsInbox {
                try inboxRepository.softDelete(id: id)
                inboxItems.removeAll { $0.id == id }
            } else {
                try transactionRepository.softDelete(id: id)
                ledgerItems.removeAll { $0.id == id }
            }
        } catch {
            // Silently handle
        }
        deleteConfirmationId = nil
    }
}
