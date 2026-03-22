import Foundation
import SharedModels
import SharedUtilities

enum TransactionDetailMode {
    case inbox(ExpenseTransactionInbox)
    case ledger(ExpenseTransaction)
}

enum TransactionDetailField: Hashable {
    case title, amount, date, account, category
}

@MainActor
@Observable
final class TransactionDetailViewModel {
    private let transactionRepository: TransactionRepository
    private let inboxRepository: InboxRepository
    private let categoryRepository: CategoryRepository
    private let bankAccountRepository: BankAccountRepository
    private let hashtagRepository: HashtagRepository
    private let transactionHashtagRepository: TransactionHashtagRepository
    private let exchangeRateRepository: ExchangeRateRepository
    private let noteEntryRepository: NoteEntryRepository
    private let entityLinkRepository: EntityLinkRepository
    private let userSettingsRepository: UserSettingsRepository
    let userId: UUID

    // Form state
    var title: String = ""
    var amountString: String = ""
    var isExpense: Bool = true
    var date: Date = Date()
    var selectedAccountId: UUID?
    var selectedCategoryId: UUID?
    var selectedHashtagIds: Set<UUID> = []
    var exchangeRate: String = "1.0"
    var descriptionText: String = ""

    // Picker data
    var accounts: [ExpenseBankAccount] = []
    var categories: [ExpenseCategory] = []
    var hashtags: [ExpenseHashtag] = []

    // Validation
    var validationErrors: Set<TransactionDetailField> = []
    var errorMessage: String?

    // State
    var mode: TransactionDetailMode?
    var isLoading: Bool = false
    var showDeleteConfirmation: Bool = false
    private(set) var currencyFormatter = CurrencyFormatter()
    private var mainCurrency: String = "USD"

    var isInbox: Bool {
        if case .inbox = mode { return true }
        return false
    }

    var canPromote: Bool {
        guard case .inbox = mode else { return false }
        let titleValid = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let amountValid = parsedAmountCents != nil
        let accountValid = selectedAccountId != nil
        let categoryValid = selectedCategoryId != nil
        let dateValid = date <= Date()
        return titleValid && amountValid && accountValid && categoryValid && dateValid
    }

    var parsedAmountCents: Int64? {
        guard let value = Double(amountString), value > 0 else { return nil }
        let cents = Int64(round(value * 100))
        return isExpense ? -cents : cents
    }

    var accountCurrency: String? {
        guard let accountId = selectedAccountId else { return nil }
        return accounts.first { $0.id == accountId }?.currencyCode
    }

    var showExchangeRate: Bool {
        guard let currency = accountCurrency else { return false }
        return currency != mainCurrency
    }

    init(
        transactionRepository: TransactionRepository,
        inboxRepository: InboxRepository,
        categoryRepository: CategoryRepository,
        bankAccountRepository: BankAccountRepository,
        hashtagRepository: HashtagRepository,
        transactionHashtagRepository: TransactionHashtagRepository,
        exchangeRateRepository: ExchangeRateRepository,
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
        self.exchangeRateRepository = exchangeRateRepository
        self.noteEntryRepository = noteEntryRepository
        self.entityLinkRepository = entityLinkRepository
        self.userSettingsRepository = userSettingsRepository
        self.userId = userId
    }

    func load(mode: TransactionDetailMode) {
        self.mode = mode
        do {
            accounts = try bankAccountRepository.fetchBankAccounts(userId: userId)
            categories = try categoryRepository.fetchAll(userId: userId)
            hashtags = try hashtagRepository.fetchAll(userId: userId)

            if let settings = try userSettingsRepository.fetchSettings(userId: userId) {
                mainCurrency = settings.mainCurrency
                currencyFormatter = CurrencyFormatter(currencyCode: settings.mainCurrency)
            }

            switch mode {
            case .inbox(let item):
                title = item.title == TransactionDescriptionService.untitledPlaceholder ? "" : item.title
                if let cents = item.amountCents {
                    isExpense = cents < 0
                    amountString = String(format: "%.2f", Double(abs(cents)) / 100.0)
                }
                if let d = item.date { date = d }
                selectedAccountId = item.accountId
                selectedCategoryId = item.categoryId
                if let rate = item.exchangeRate {
                    exchangeRate = "\(rate)"
                }
                loadHashtags(transactionId: item.id, source: .inbox)
                loadDescription(sourceType: .expenseInbox, sourceId: item.id)

            case .ledger(let transaction):
                title = transaction.title
                isExpense = transaction.amountCents < 0
                amountString = String(format: "%.2f", Double(abs(transaction.amountCents)) / 100.0)
                date = transaction.date
                selectedAccountId = transaction.accountId
                selectedCategoryId = transaction.categoryId
                exchangeRate = "\(transaction.exchangeRate)"
                loadHashtags(transactionId: transaction.id, source: .ledger)
                loadDescription(sourceType: .expenseLedger, sourceId: transaction.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() {
        validationErrors = []
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { validationErrors.insert(.title) }

        do {
            switch mode {
            case .inbox(let item):
                item.title = trimmedTitle.isEmpty ? TransactionDescriptionService.untitledPlaceholder : trimmedTitle
                item.amountCents = parsedAmountCents
                item.date = date
                item.accountId = selectedAccountId
                item.categoryId = selectedCategoryId
                if let rate = Decimal(string: exchangeRate) {
                    item.exchangeRate = rate
                }
                try inboxRepository.update(item)
                saveHashtags(transactionId: item.id, source: .inbox)
                saveDescription(sourceType: .expenseInbox, sourceId: item.id)

            case .ledger(let transaction):
                if parsedAmountCents == nil { validationErrors.insert(.amount) }
                if selectedAccountId == nil { validationErrors.insert(.account) }
                if selectedCategoryId == nil { validationErrors.insert(.category) }
                guard validationErrors.isEmpty else { return }

                guard let amountCents = parsedAmountCents,
                      let accountId = selectedAccountId,
                      let categoryId = selectedCategoryId else {
                    assertionFailure("Validation passed but required fields were nil")
                    errorMessage = "Something went wrong. Please try again."
                    return
                }

                transaction.title = trimmedTitle
                transaction.amountCents = amountCents
                transaction.date = date
                transaction.accountId = accountId
                transaction.categoryId = categoryId
                if let rate = Decimal(string: exchangeRate) {
                    transaction.exchangeRate = rate
                }
                try transactionRepository.update(transaction)
                saveHashtags(transactionId: transaction.id, source: .ledger)
                saveDescription(sourceType: .expenseLedger, sourceId: transaction.id)

            case .none:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func promote() {
        guard case .inbox(let item) = mode else { return }

        validationErrors = []
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { validationErrors.insert(.title) }
        if parsedAmountCents == nil { validationErrors.insert(.amount) }
        if selectedAccountId == nil { validationErrors.insert(.account) }
        if selectedCategoryId == nil { validationErrors.insert(.category) }
        if date > Date() { validationErrors.insert(.date) }
        guard validationErrors.isEmpty else { return }

        guard let amountCents = parsedAmountCents,
              let accountId = selectedAccountId,
              let categoryId = selectedCategoryId else {
            assertionFailure("Validation passed but required fields were nil")
            errorMessage = "Something went wrong. Please try again."
            return
        }

        do {
            let transaction = ExpenseTransaction(
                userId: userId,
                title: trimmedTitle,
                amountCents: amountCents,
                date: date,
                accountId: accountId,
                categoryId: categoryId,
                exchangeRate: Decimal(string: exchangeRate) ?? 1.0,
                inboxId: item.id,
                sourceText: item.sourceText
            )
            try transactionRepository.create(transaction)

            // Copy hashtag links
            let inboxHashtags = try transactionHashtagRepository.fetchForTransaction(
                transactionId: item.id, source: .inbox
            )
            for link in inboxHashtags {
                try transactionHashtagRepository.link(
                    transactionId: transaction.id,
                    source: .ledger,
                    hashtagId: link.hashtagId,
                    userId: userId
                )
            }

            // Migrate description entity link if exists
            try TransactionDescriptionService.migrateLink(
                fromSourceType: .expenseInbox,
                fromSourceId: item.id,
                toSourceType: .expenseLedger,
                toSourceId: transaction.id,
                userId: userId,
                entityLinkRepository: entityLinkRepository
            )

            // Soft-delete inbox record
            try inboxRepository.softDelete(id: item.id)

            mode = .ledger(transaction)
            load(mode: .ledger(transaction))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTransaction() {
        do {
            switch mode {
            case .inbox(let item):
                try transactionHashtagRepository.unlinkAll(transactionId: item.id, source: .inbox)
                try entityLinkRepository.softDelete(sourceType: .expenseInbox, sourceId: item.id)
                try inboxRepository.softDelete(id: item.id)
            case .ledger(let transaction):
                try transactionHashtagRepository.unlinkAll(transactionId: transaction.id, source: .ledger)
                try entityLinkRepository.softDelete(sourceType: .expenseLedger, sourceId: transaction.id)
                try transactionRepository.softDelete(id: transaction.id)
            case .none:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func autoPopulateExchangeRate() {
        guard let currency = accountCurrency, currency != mainCurrency else { return }
        do {
            if let rate = try exchangeRateRepository.fetchRate(base: currency, target: mainCurrency, date: date) {
                exchangeRate = "\(rate.rate)"
            } else if let rate = try exchangeRateRepository.fetchLatestRate(base: currency, target: mainCurrency) {
                exchangeRate = "\(rate.rate)"
            }
        } catch {
            // User can enter manually
        }
    }

    // MARK: - Create Inline

    func createCategory(name: String) {
        let category = ExpenseCategory(
            userId: userId,
            name: name,
            categoryType: .expense,
            color: TransactionDescriptionService.defaultCategoryColor
        )
        do {
            try categoryRepository.create(category)
            categories.append(category)
            selectedCategoryId = category.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createHashtag(name: String) {
        let hashtag = ExpenseHashtag(userId: userId, name: name)
        do {
            try hashtagRepository.create(hashtag)
            hashtags.append(hashtag)
            selectedHashtagIds.insert(hashtag.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func loadHashtags(transactionId: UUID, source: TransactionSourceType) {
        do {
            let links = try transactionHashtagRepository.fetchForTransaction(
                transactionId: transactionId, source: source
            )
            selectedHashtagIds = Set(links.map(\.hashtagId))
        } catch {
            errorMessage = "Failed to load hashtags: \(error.localizedDescription)"
        }
    }

    private func loadDescription(sourceType: EntitySourceType, sourceId: UUID) {
        do {
            descriptionText = try TransactionDescriptionService.loadDescription(
                sourceType: sourceType,
                sourceId: sourceId,
                noteEntryRepository: noteEntryRepository,
                entityLinkRepository: entityLinkRepository
            )
        } catch {
            errorMessage = "Failed to load description: \(error.localizedDescription)"
        }
    }

    private func saveHashtags(transactionId: UUID, source: TransactionSourceType) {
        do {
            let existing = try transactionHashtagRepository.fetchForTransaction(
                transactionId: transactionId, source: source
            )
            let existingIds = Set(existing.map(\.hashtagId))

            for hashtagId in selectedHashtagIds where !existingIds.contains(hashtagId) {
                try transactionHashtagRepository.link(
                    transactionId: transactionId,
                    source: source,
                    hashtagId: hashtagId,
                    userId: userId
                )
            }

            for hashtagId in existingIds where !selectedHashtagIds.contains(hashtagId) {
                try transactionHashtagRepository.unlink(
                    transactionId: transactionId,
                    source: source,
                    hashtagId: hashtagId
                )
            }
        } catch {
            errorMessage = "Failed to save hashtags: \(error.localizedDescription)"
        }
    }

    func saveDescription(sourceType: EntitySourceType, sourceId: UUID) {
        do {
            try TransactionDescriptionService.saveDescription(
                userId: userId,
                sourceType: sourceType,
                sourceId: sourceId,
                content: descriptionText,
                noteEntryRepository: noteEntryRepository,
                entityLinkRepository: entityLinkRepository
            )
        } catch {
            errorMessage = "Failed to save description: \(error.localizedDescription)"
        }
    }
}
