import Foundation
import SharedModels
import SharedUtilities
import SharedUI

@MainActor
@Observable
final class AddTransactionViewModel {
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
    private let userId: UUID

    // MARK: - Amount Entry

    /// Raw amount string managed by the numpad (e.g., "45.00").
    var amountString: String = ""
    var isExpense: Bool = true

    // MARK: - Field Values

    var title: String = ""
    var date: Date = Date()
    var selectedCategoryId: UUID?
    var selectedAccountId: UUID?
    var selectedHashtagIds: Set<UUID> = []
    var descriptionText: String = ""
    var exchangeRate: String = "1.0"

    // MARK: - Picker Data

    var accounts: [ExpenseBankAccount] = []
    var categories: [ExpenseCategory] = []
    var hashtags: [ExpenseHashtag] = []

    // MARK: - UI State

    var errorMessage: String?
    var isSubmitting: Bool = false
    var showSaveConfirmation: Bool = false
    private(set) var mainCurrency: String = "USD"

    // MARK: - Init

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

    // MARK: - Computed Properties

    /// The currency code from the selected account, or mainCurrency if none.
    var accountCurrency: String {
        guard let id = selectedAccountId,
              let account = accounts.first(where: { $0.id == id }) else {
            return mainCurrency
        }
        return account.currencyCode
    }

    /// Whether to show exchange rate information (account currency differs from main).
    var showExchangeRate: Bool {
        accountCurrency != mainCurrency
    }

    /// Parsed amount in cents, signed based on isExpense toggle.
    var amountCents: Int64? {
        guard !amountString.isEmpty else { return nil }
        guard let decimal = Decimal(string: amountString), decimal > 0 else { return nil }
        let cents = NSDecimalNumber(decimal: decimal * 100).int64Value
        return isExpense ? -cents : cents
    }

    /// Formatted display string for the amount hero.
    var formattedAmount: String {
        if amountString.isEmpty { return "0.00" }
        return amountString
    }

    /// Whether all required fields are present for a ledger entry.
    var canGoToLedger: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAmount = amountCents != nil
        let hasAccount = selectedAccountId != nil
        let hasCategory = selectedCategoryId != nil
        let dateValid = date <= Date()
        return hasTitle && hasAmount && hasAccount && hasCategory && dateValid
    }

    /// Whether any meaningful data has been entered (amount > 0).
    var hasAnyData: Bool {
        amountCents != nil
    }

    enum SaveButtonState {
        case disabled
        case draft
        case ledger
    }

    var saveButtonState: SaveButtonState {
        if !hasAnyData { return .disabled }
        if canGoToLedger { return .ledger }
        return .draft
    }

    /// Selected category object (for display).
    var selectedCategory: ExpenseCategory? {
        guard let id = selectedCategoryId else { return nil }
        return categories.first { $0.id == id }
    }

    /// Selected account object (for display).
    var selectedAccount: ExpenseBankAccount? {
        guard let id = selectedAccountId else { return nil }
        return accounts.first { $0.id == id }
    }

    /// Selected hashtags (for display).
    var selectedHashtags: [ExpenseHashtag] {
        hashtags.filter { selectedHashtagIds.contains($0.id) }
    }

    /// Whether the description has content.
    var hasDescription: Bool {
        !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Numpad Input

    func handleNumpadKey(_ key: NumpadKey) {
        switch key {
        case .digit(let d):
            // Don't allow leading zeros (except "0.")
            if amountString == "0" && d == 0 { return }
            if amountString == "0" && d != 0 { amountString = "" }

            // Max 2 decimal places
            if let dotIndex = amountString.firstIndex(of: ".") {
                let decimals = amountString[amountString.index(after: dotIndex)...]
                if decimals.count >= 2 { return }
            }

            // Max 8 digits before decimal (prevents overflow)
            let integerPart = amountString.components(separatedBy: ".").first ?? amountString
            if !amountString.contains(".") && integerPart.count >= 8 { return }

            amountString.append(String(d))

        case .decimal:
            if amountString.contains(".") { return }
            if amountString.isEmpty { amountString = "0" }
            amountString.append(".")

        case .backspace:
            if !amountString.isEmpty {
                amountString.removeLast()
            }
        }
    }

    // MARK: - Lifecycle

    func loadPickerData() {
        do {
            accounts = try bankAccountRepository.fetchBankAccounts(userId: userId)
            categories = try categoryRepository.fetchAll(userId: userId)
            hashtags = try hashtagRepository.fetchAll(userId: userId)
            if let settings = try userSettingsRepository.fetchSettings(userId: userId) {
                mainCurrency = settings.mainCurrency
            }
            resolveDefaultAccount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Smart default: set account to the most recently used one.
    private func resolveDefaultAccount() {
        do {
            if let recent = try transactionRepository.fetchMostRecent(userId: userId) {
                selectedAccountId = recent.accountId
            } else if let first = accounts.first {
                selectedAccountId = first.id
            }
        } catch {
            if let first = accounts.first {
                selectedAccountId = first.id
            }
        }
    }

    // MARK: - Exchange Rate

    func autoPopulateExchangeRate() {
        guard let accountId = selectedAccountId,
              let account = accounts.first(where: { $0.id == accountId }) else {
            exchangeRate = "1.0"
            return
        }
        let currency = account.currencyCode
        guard currency != mainCurrency else {
            exchangeRate = "1.0"
            return
        }
        do {
            if let rate = try exchangeRateRepository.fetchRate(base: currency, target: mainCurrency, date: date) {
                exchangeRate = "\(rate.rate)"
            } else if let rate = try exchangeRateRepository.fetchLatestRate(base: currency, target: mainCurrency) {
                exchangeRate = "\(rate.rate)"
            }
        } catch {
            // Keep current rate
        }
    }

    // MARK: - Inline Creation

    func createCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let category = ExpenseCategory(
                userId: userId,
                name: trimmed,
                categoryType: isExpense ? .expense : .income,
                color: TransactionDescriptionService.defaultCategoryColor
            )
            try categoryRepository.create(category)
            categories.append(category)
            selectedCategoryId = category.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createHashtag(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let hashtag = ExpenseHashtag(userId: userId, name: trimmed)
            try hashtagRepository.create(hashtag)
            hashtags.append(hashtag)
            selectedHashtagIds.insert(hashtag.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Submit

    func submit() {
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            let amount = amountCents
            let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = resolvedTitle.isEmpty ? TransactionDescriptionService.untitledPlaceholder : resolvedTitle

            // Resolve exchange rate
            var resolvedExchangeRate: Decimal = 1.0
            if let rateDecimal = Decimal(string: exchangeRate) {
                resolvedExchangeRate = rateDecimal
            }

            // Resolve hashtag IDs
            let hashtagIds = Array(selectedHashtagIds)

            // Route: ledger or inbox?
            if let amount, let accountId = selectedAccountId, let categoryId = selectedCategoryId,
               finalTitle != TransactionDescriptionService.untitledPlaceholder, date <= Date() {
                // -> Ledger
                let transaction = ExpenseTransaction(
                    userId: userId,
                    title: finalTitle,
                    amountCents: amount,
                    date: date,
                    accountId: accountId,
                    categoryId: categoryId,
                    exchangeRate: resolvedExchangeRate,
                    sourceText: nil
                )
                try transactionRepository.create(transaction)

                for hashtagId in hashtagIds {
                    try transactionHashtagRepository.link(
                        transactionId: transaction.id,
                        source: .ledger,
                        hashtagId: hashtagId,
                        userId: userId
                    )
                }

                saveDescription(sourceType: .expenseLedger, sourceId: transaction.id)
            } else {
                // -> Inbox
                let inbox = ExpenseTransactionInbox(
                    userId: userId,
                    title: finalTitle,
                    amountCents: amount,
                    date: date,
                    accountId: selectedAccountId,
                    categoryId: selectedCategoryId,
                    exchangeRate: resolvedExchangeRate,
                    sourceText: nil
                )
                try inboxRepository.create(inbox)

                for hashtagId in hashtagIds {
                    try transactionHashtagRepository.link(
                        transactionId: inbox.id,
                        source: .inbox,
                        hashtagId: hashtagId,
                        userId: userId
                    )
                }

                saveDescription(sourceType: .expenseInbox, sourceId: inbox.id)
            }

            // Success — trigger confirmation and reset for batch entry
            showSaveConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Resets fields for the next entry in batch mode.
    /// Keeps: date, account, isExpense (most likely the same for consecutive entries).
    func resetForNextEntry() {
        amountString = ""
        title = ""
        descriptionText = ""
        selectedCategoryId = nil
        selectedHashtagIds = []
        errorMessage = nil
        showSaveConfirmation = false
    }

    // MARK: - Private

    private func saveDescription(sourceType: EntitySourceType, sourceId: UUID) {
        let trimmed = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try TransactionDescriptionService.createLinkedNote(
                userId: userId,
                sourceType: sourceType,
                sourceId: sourceId,
                content: trimmed,
                noteEntryRepository: noteEntryRepository,
                entityLinkRepository: entityLinkRepository
            )
        } catch {
            errorMessage = "Failed to save description: \(error.localizedDescription)"
        }
    }
}
