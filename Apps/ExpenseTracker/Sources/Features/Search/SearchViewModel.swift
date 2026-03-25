import Foundation
import SharedModels
import SharedUtilities

@MainActor
@Observable
final class SearchViewModel {
    private let transactionRepository: TransactionRepository
    private let inboxRepository: InboxRepository
    private let categoryRepository: CategoryRepository
    private let bankAccountRepository: BankAccountRepository
    private let hashtagRepository: HashtagRepository
    private let transactionHashtagRepository: TransactionHashtagRepository
    private let noteEntryRepository: NoteEntryRepository
    private let entityLinkRepository: EntityLinkRepository
    private let userSettingsRepository: UserSettingsRepository
    private let userId: UUID

    var query: String = ""
    var results: [ExpenseTransaction] = []
    var inboxResults: [ExpenseTransactionInbox] = []
    var errorMessage: String?
    private(set) var currencyFormatter = CurrencyFormatter()

    // Lookup dictionaries
    private(set) var categoryNames: [UUID: String] = [:]
    private(set) var categoryColors: [UUID: String] = [:]
    private(set) var accountNames: [UUID: String] = [:]
    private var hashtagNames: [UUID: String] = [:]
    private var transactionHashtags: [UUID: Set<UUID>] = [:]  // transactionId → hashtagIds
    private var transactionNotes: [UUID: String] = [:]          // transactionId → note content

    // Detail modal
    var selectedLedgerItem: ExpenseTransaction?
    var selectedInboxItem: ExpenseTransactionInbox?
    var showDetail: Bool = false

    init(
        transactionRepository: TransactionRepository,
        inboxRepository: InboxRepository,
        categoryRepository: CategoryRepository,
        bankAccountRepository: BankAccountRepository,
        hashtagRepository: HashtagRepository,
        transactionHashtagRepository: TransactionHashtagRepository,
        noteEntryRepository: NoteEntryRepository,
        entityLinkRepository: EntityLinkRepository,
        userSettingsRepository: UserSettingsRepository,
        userId: UUID
    ) {
        self.transactionRepository = transactionRepository
        self.inboxRepository = inboxRepository
        self.categoryRepository = categoryRepository
        self.bankAccountRepository = bankAccountRepository
        self.hashtagRepository = hashtagRepository
        self.transactionHashtagRepository = transactionHashtagRepository
        self.noteEntryRepository = noteEntryRepository
        self.entityLinkRepository = entityLinkRepository
        self.userSettingsRepository = userSettingsRepository
        self.userId = userId
    }

    func loadLookups() {
        do {
            if let settings = try userSettingsRepository.fetchSettings(userId: userId) {
                currencyFormatter = CurrencyFormatter(currencyCode: settings.mainCurrency)
            }

            // Build category name lookup
            let categories = try categoryRepository.fetchAll(userId: userId)
            categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
            categoryColors = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.color) })

            // Build account name lookup
            let accounts = try bankAccountRepository.fetchAll(userId: userId)
            accountNames = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) })

            // Build hashtag name lookup
            let hashtags = try hashtagRepository.fetchAll(userId: userId)
            hashtagNames = Dictionary(uniqueKeysWithValues: hashtags.map { ($0.id, $0.name) })
        } catch {
            errorMessage = "Failed to load search data: \(error.localizedDescription)"
        }
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            results = []
            inboxResults = []
            return
        }

        do {
            // Search ledger
            let allTransactions = try transactionRepository.fetchAll(userId: userId)
            results = allTransactions.filter { matches(transaction: $0, query: trimmed) }

            // Search inbox
            let allInbox = try inboxRepository.fetchAll(userId: userId)
            inboxResults = allInbox.filter { matchesInbox(item: $0, query: trimmed) }
        } catch {
            results = []
            inboxResults = []
        }
    }

    private func matches(transaction: ExpenseTransaction, query: String) -> Bool {
        // Title
        if transaction.title.lowercased().contains(query) { return true }

        // Category name
        if let name = categoryNames[transaction.categoryId],
           name.lowercased().contains(query) { return true }

        // Account name
        if let name = accountNames[transaction.accountId],
           name.lowercased().contains(query) { return true }

        // Amount — format and check
        let amountStr = currencyFormatter.format(transaction.amountCents).lowercased()
        if amountStr.contains(query) { return true }
        // Also check raw number
        let rawAmount = String(format: "%.2f", Double(abs(transaction.amountCents)) / 100.0)
        if rawAmount.contains(query) { return true }

        // Hashtags
        if matchesHashtags(transactionId: transaction.id, source: .ledger, query: query) { return true }

        // Description (NoteEntry via EntityLink)
        if matchesDescription(sourceType: .expenseLedger, sourceId: transaction.id, query: query) { return true }

        return false
    }

    private func matchesInbox(item: ExpenseTransactionInbox, query: String) -> Bool {
        // Title
        if item.title.lowercased().contains(query) { return true }

        // Category name
        if let categoryId = item.categoryId, let name = categoryNames[categoryId],
           name.lowercased().contains(query) { return true }

        // Account name
        if let accountId = item.accountId, let name = accountNames[accountId],
           name.lowercased().contains(query) { return true }

        // Amount
        if let cents = item.amountCents {
            let rawAmount = String(format: "%.2f", Double(abs(cents)) / 100.0)
            if rawAmount.contains(query) { return true }
        }

        // Hashtags
        if matchesHashtags(transactionId: item.id, source: .inbox, query: query) { return true }

        // Description
        if matchesDescription(sourceType: .expenseInbox, sourceId: item.id, query: query) { return true }

        return false
    }

    private func matchesHashtags(transactionId: UUID, source: TransactionSourceType, query: String) -> Bool {
        do {
            let links = try transactionHashtagRepository.fetchForTransaction(
                transactionId: transactionId, source: source
            )
            for link in links {
                if let name = hashtagNames[link.hashtagId],
                   name.lowercased().contains(query) {
                    return true
                }
            }
        } catch {
            #if DEBUG
            print("[Search] Failed to match hashtags for \(transactionId): \(error)")
            #endif
        }
        return false
    }

    private func matchesDescription(sourceType: EntitySourceType, sourceId: UUID, query: String) -> Bool {
        do {
            if let noteId = try entityLinkRepository.fetchTargetId(
                sourceType: sourceType,
                sourceId: sourceId,
                targetType: .note,
                context: .expenseNote
            ) {
                if let note = try noteEntryRepository.fetchById(noteId),
                   let content = note.content,
                   content.lowercased().contains(query) {
                    return true
                }
            }
        } catch {
            #if DEBUG
            print("[Search] Failed to match description for \(sourceId): \(error)")
            #endif
        }
        return false
    }

    // MARK: - Selection

    func selectLedgerItem(_ item: ExpenseTransaction) {
        selectedLedgerItem = item
        selectedInboxItem = nil
        showDetail = true
    }

    func selectInboxItem(_ item: ExpenseTransactionInbox) {
        selectedInboxItem = item
        selectedLedgerItem = nil
        showDetail = true
    }

    func dismissDetail() {
        showDetail = false
        selectedLedgerItem = nil
        selectedInboxItem = nil
    }
}
