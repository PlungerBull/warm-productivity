import Foundation
import SharedModels

@MainActor
@Observable
final class OnboardingViewModel {
    private let userSettingsRepository: UserSettingsRepository
    private let bankAccountRepository: BankAccountRepository
    private let categoryRepository: CategoryRepository
    private let transactionRepository: TransactionRepository
    private let currencyRepository: CurrencyRepository
    private let noteEntryRepository: NoteEntryRepository
    private let entityLinkRepository: EntityLinkRepository
    private let currencySyncService: CurrencySyncService
    private let userId: UUID

    // Form state
    var selectedCurrencyCode: String = "USD"
    var bankAccountName: String = ""
    var errorMessage: String?
    var isCompleting: Bool = false
    var isLoadingCurrencies: Bool = false
    var currencies: [GlobalCurrency] = []

    var isValid: Bool {
        !bankAccountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedCurrencyCode.isEmpty
    }

    init(
        userId: UUID,
        userSettingsRepository: UserSettingsRepository,
        bankAccountRepository: BankAccountRepository,
        categoryRepository: CategoryRepository,
        transactionRepository: TransactionRepository,
        currencyRepository: CurrencyRepository,
        noteEntryRepository: NoteEntryRepository,
        entityLinkRepository: EntityLinkRepository,
        currencySyncService: CurrencySyncService
    ) {
        self.userId = userId
        self.userSettingsRepository = userSettingsRepository
        self.bankAccountRepository = bankAccountRepository
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
        self.currencyRepository = currencyRepository
        self.noteEntryRepository = noteEntryRepository
        self.entityLinkRepository = entityLinkRepository
        self.currencySyncService = currencySyncService
    }

    /// Load currencies from Supabase into local SwiftData, then fetch locally.
    func loadCurrencies() async {
        isLoadingCurrencies = true
        defer { isLoadingCurrencies = false }
        do {
            try await currencySyncService.syncFromRemote()
            currencies = try currencyRepository.fetchAll()
        } catch {
            // If sync fails, try loading whatever is cached locally
            currencies = (try? currencyRepository.fetchAll()) ?? []
            if currencies.isEmpty {
                errorMessage = "Failed to load currencies: \(error.localizedDescription)"
            }
        }
    }

    /// Complete the onboarding setup flow.
    /// 1. Create UserSettings with chosen currency
    /// 2. Create first bank account
    /// 3. Create @Other system category
    /// 4. Create 2 demo transactions
    func completeSetup() throws {
        isCompleting = true
        defer { isCompleting = false }

        do {
            // 1. Create user settings
            try userSettingsRepository.createSettings(
                userId: userId,
                mainCurrency: selectedCurrencyCode
            )

            // 2. Create first bank account
            let trimmedName = bankAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
            let account = ExpenseBankAccount(
                userId: userId,
                name: trimmedName,
                currencyCode: selectedCurrencyCode
            )
            try bankAccountRepository.create(account)

            // 3. Create @Other system category
            let otherCategory = try categoryRepository.ensureOtherCategory(userId: userId)

            // 4. Create demo transactions
            try createDemoTransactions(accountId: account.id, categoryId: otherCategory.id)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func createDemoTransactions(accountId: UUID, categoryId: UUID) throws {
        let today = Date()

        // Demo Transaction 1 — Expense: Morning Coffee (-12.00)
        let coffeeTransaction = ExpenseTransaction(
            userId: userId,
            title: "Morning Coffee",
            amountCents: -1200,
            date: today,
            accountId: accountId,
            categoryId: categoryId,
            sourceText: "onboarding"
        )
        try transactionRepository.create(coffeeTransaction)
        try createDescription(
            for: coffeeTransaction.id,
            content: "Welcome! This is a demo expense transaction. It shows how a typical expense looks — with a title, amount, date, account, and category. Tap to edit any field, or swipe to delete.\n\nDelete this transaction when you're ready to get started."
        )

        // Demo Transaction 2 — Income: Monthly Salary (+3,000.00)
        let salaryTransaction = ExpenseTransaction(
            userId: userId,
            title: "Monthly Salary",
            amountCents: 300_000,
            date: today,
            accountId: accountId,
            categoryId: categoryId,
            sourceText: "onboarding"
        )
        try transactionRepository.create(salaryTransaction)
        try createDescription(
            for: salaryTransaction.id,
            content: "This is a demo income transaction. Income uses positive amounts, expenses use negative. You can add notes like this one to any transaction to keep context about what it's for.\n\nDelete this transaction when you're ready to get started."
        )
    }

    private func createDescription(for transactionId: UUID, content: String) throws {
        try TransactionDescriptionService.createLinkedNote(
            userId: userId,
            sourceType: .expenseLedger,
            sourceId: transactionId,
            content: content,
            noteEntryRepository: noteEntryRepository,
            entityLinkRepository: entityLinkRepository
        )
    }

    func clearError() {
        errorMessage = nil
    }
}

