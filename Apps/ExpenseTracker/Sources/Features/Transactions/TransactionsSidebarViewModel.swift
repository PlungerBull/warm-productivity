import Foundation
import SharedModels
import SharedUtilities

@MainActor
@Observable
final class TransactionsSidebarViewModel {
    private let bankAccountRepository: BankAccountRepository
    private let categoryRepository: CategoryRepository
    private let transactionRepository: TransactionRepository
    private let inboxRepository: InboxRepository
    private let hashtagRepository: HashtagRepository
    private let currencyRepository: CurrencyRepository
    private let userSettingsRepository: UserSettingsRepository
    let userId: UUID

    var bankAccounts: [ExpenseBankAccount] = []
    var categories: [ExpenseCategory] = []
    var hashtags: [ExpenseHashtag] = []
    var currencies: [GlobalCurrency] = []
    var accountBalances: [UUID: Int64] = [:]
    var categorySpend: [UUID: Int64] = [:]
    var inboxCount: Int = 0
    var settings: UserSettings?
    private(set) var currencyFormatter = CurrencyFormatter()

    // Inline creation state
    var showCreateAccount: Bool = false
    var showCreateCategory: Bool = false
    var showCreateHashtag: Bool = false
    var newItemName: String = ""
    var newAccountCurrency: String = "USD"
    var errorMessage: String?

    // Rename state
    var renamingItemId: UUID?
    var renameText: String = ""

    init(
        bankAccountRepository: BankAccountRepository,
        categoryRepository: CategoryRepository,
        transactionRepository: TransactionRepository,
        inboxRepository: InboxRepository,
        hashtagRepository: HashtagRepository,
        currencyRepository: CurrencyRepository,
        userSettingsRepository: UserSettingsRepository,
        userId: UUID
    ) {
        self.bankAccountRepository = bankAccountRepository
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
        self.inboxRepository = inboxRepository
        self.hashtagRepository = hashtagRepository
        self.currencyRepository = currencyRepository
        self.userSettingsRepository = userSettingsRepository
        self.userId = userId
    }

    func loadSidebar() {
        do {
            bankAccounts = try bankAccountRepository.fetchBankAccounts(userId: userId)
            categories = try categoryRepository.fetchAll(userId: userId)
            hashtags = try hashtagRepository.fetchAll(userId: userId)
            currencies = try currencyRepository.fetchAll()
            settings = try userSettingsRepository.fetchSettings(userId: userId)
            newAccountCurrency = settings?.mainCurrency ?? "USD"
            currencyFormatter = CurrencyFormatter(currencyCode: settings?.mainCurrency ?? "USD")
            inboxCount = try inboxRepository.count(userId: userId)

            var balances: [UUID: Int64] = [:]
            for account in bankAccounts {
                balances[account.id] = try transactionRepository.runningBalanceCents(
                    userId: userId, accountId: account.id
                )
            }
            accountBalances = balances

            var spend: [UUID: Int64] = [:]
            for category in categories {
                spend[category.id] = try transactionRepository.currentMonthSpendCents(
                    userId: userId, categoryId: category.id
                )
            }
            categorySpend = spend
        } catch {
            // Silently handle
        }
    }

    // MARK: - Bank Account CRUD

    func createAccount(name: String, currencyCode: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let account = ExpenseBankAccount(
            userId: userId,
            name: trimmed,
            currencyCode: currencyCode
        )
        do {
            try bankAccountRepository.create(account)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameAccount(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try bankAccountRepository.update(id: id, name: trimmed)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archiveAccount(id: UUID) {
        do {
            try bankAccountRepository.archive(id: id)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveAccounts(from source: IndexSet, to destination: Int) {
        bankAccounts.move(fromOffsets: source, toOffset: destination)
        for (index, account) in bankAccounts.enumerated() {
            try? bankAccountRepository.updateSortOrder(id: account.id, sortOrder: index)
        }
    }

    // MARK: - Category CRUD

    func createCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let category = ExpenseCategory(
            userId: userId,
            name: trimmed,
            categoryType: .expense,
            color: TransactionDescriptionService.defaultCategoryColor
        )
        do {
            try categoryRepository.create(category)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameCategory(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try categoryRepository.update(id: id, name: trimmed)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(id: UUID) {
        do {
            try categoryRepository.softDelete(id: id)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        for (index, category) in categories.enumerated() {
            try? categoryRepository.updateSortOrder(id: category.id, sortOrder: index)
        }
    }

    func isSystemCategory(_ category: ExpenseCategory) -> Bool {
        CategoryRepository.systemCategoryNames.contains(category.name)
    }

    // MARK: - Hashtag CRUD

    func createHashtag(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hashtag = ExpenseHashtag(userId: userId, name: trimmed)
        do {
            try hashtagRepository.create(hashtag)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameHashtag(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try hashtagRepository.update(id: id, name: trimmed)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteHashtag(id: UUID) {
        do {
            try hashtagRepository.softDelete(id: id)
            loadSidebar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveHashtags(from source: IndexSet, to destination: Int) {
        hashtags.move(fromOffsets: source, toOffset: destination)
        for (index, hashtag) in hashtags.enumerated() {
            try? hashtagRepository.updateSortOrder(id: hashtag.id, sortOrder: index)
        }
    }
}
