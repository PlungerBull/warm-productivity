import Foundation
import SwiftUI
import SharedModels
import SharedUI
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
    private let categoryRepository: CategoryRepository
    private let bankAccountRepository: BankAccountRepository
    private let userSettingsRepository: UserSettingsRepository
    private let userId: UUID

    var ledgerItems: [ExpenseTransaction] = []
    var inboxItems: [ExpenseTransactionInbox] = []
    private(set) var currencyFormatter = CurrencyFormatter()

    // Lookup data for row rendering
    private(set) var categoryLookup: [UUID: ExpenseCategory] = [:]
    private(set) var accountLookup: [UUID: ExpenseBankAccount] = [:]

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
        categoryRepository: CategoryRepository,
        bankAccountRepository: BankAccountRepository,
        userSettingsRepository: UserSettingsRepository,
        userId: UUID
    ) {
        self.transactionRepository = transactionRepository
        self.inboxRepository = inboxRepository
        self.transactionHashtagRepository = transactionHashtagRepository
        self.categoryRepository = categoryRepository
        self.bankAccountRepository = bankAccountRepository
        self.userSettingsRepository = userSettingsRepository
        self.userId = userId
    }

    func load(destination: SidebarDestination) {
        do {
            if let settings = try userSettingsRepository.fetchSettings(userId: userId) {
                currencyFormatter = CurrencyFormatter(currencyCode: settings.mainCurrency)
            }

            // Load lookup data for row rendering
            let categories = try categoryRepository.fetchAll(userId: userId)
            categoryLookup = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

            let accounts = try bankAccountRepository.fetchAll(userId: userId)
            accountLookup = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })

            switch destination {
            case .inbox:
                inboxItems = try inboxRepository.fetchAll(userId: userId)
                ledgerItems = []
            case .ledger:
                ledgerItems = try transactionRepository.fetchAll(userId: userId)
                inboxItems = []
            case .bankAccount(let id, _):
                ledgerItems = try transactionRepository.fetchByAccount(userId: userId, accountId: id)
                inboxItems = []
            case .category(let id, _):
                ledgerItems = try transactionRepository.fetchByCategory(userId: userId, categoryId: id)
                inboxItems = []
            case .hashtag(let id, _):
                let transactionIds = try transactionHashtagRepository.fetchTransactionIds(hashtagId: id)
                ledgerItems = try transactionRepository.fetchByIds(userId: userId, ids: transactionIds)
                inboxItems = []
            }
        } catch {
            ledgerItems = []
            inboxItems = []
        }
    }

    // MARK: - Lookup Helpers

    func categoryColor(for categoryId: UUID) -> Color {
        guard let hex = categoryLookup[categoryId]?.color else { return Color.wpTextTertiary }
        return Color(hex: hex)
    }

    func accountName(for accountId: UUID) -> String {
        accountLookup[accountId]?.name ?? ""
    }

    func accountCurrencyFormatter(for accountId: UUID) -> CurrencyFormatter {
        guard let code = accountLookup[accountId]?.currencyCode else { return currencyFormatter }
        return CurrencyFormatter(currencyCode: code)
    }

    func isReadyToPromote(_ item: ExpenseTransactionInbox) -> Bool {
        let hasTitle = item.title != "UNTITLED" && !item.title.isEmpty
        let hasAmount = item.amountCents != nil
        let hasAccount = item.accountId != nil
        let hasCategory = item.categoryId != nil
        let hasValidDate: Bool = {
            guard let date = item.date else { return false }
            return date <= Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        }()
        return hasTitle && hasAmount && hasAccount && hasCategory && hasValidDate
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
