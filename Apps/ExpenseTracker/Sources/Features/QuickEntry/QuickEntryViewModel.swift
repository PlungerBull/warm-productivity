import Foundation
import SharedModels
import SharedUtilities

@MainActor
@Observable
final class QuickEntryViewModel {
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
    private let parser = CommandParser()

    // Input
    var commandText: String = ""
    var descriptionText: String = ""

    // Parsed state (updated as user types)
    var parsedTitle: String?
    var parsedAmountCents: Int64?
    var parsedCategoryName: String?
    var parsedAccountName: String?
    var parsedHashtags: [String] = []
    var parsedDate: Date?

    // Override state (user can manually set these via toolbar buttons)
    var overrideDate: Date?
    var overrideCategoryId: UUID?
    var overrideAccountId: UUID?

    // Picker data
    var accounts: [ExpenseBankAccount] = []
    var categories: [ExpenseCategory] = []
    var hashtags: [ExpenseHashtag] = []

    // UI state
    var errorMessage: String?
    var isSubmitting: Bool = false
    private(set) var mainCurrency: String = "USD"

    /// Whether the parsed command has enough data to go directly to ledger.
    var canGoToLedger: Bool {
        let hasTitle = !(parsedTitle?.isEmpty ?? true)
        let hasAmount = parsedAmountCents != nil
        let hasAccount = resolvedAccountId != nil
        let hasCategory = resolvedCategoryId != nil
        let hasDate = resolvedDate.map { $0 <= Date() } ?? false
        return hasTitle && hasAmount && hasAccount && hasCategory && hasDate
    }

    var submitLabel: String {
        canGoToLedger ? "Add to Ledger" : "Add to Inbox"
    }

    var resolvedAccountId: UUID? {
        if let id = overrideAccountId { return id }
        guard let name = parsedAccountName else { return nil }
        return accounts.first { $0.name.lowercased() == name.lowercased() }?.id
    }

    var resolvedCategoryId: UUID? {
        if let id = overrideCategoryId { return id }
        guard let name = parsedCategoryName else { return nil }
        return categories.first { $0.name.lowercased() == name.lowercased() }?.id
    }

    var resolvedDate: Date? {
        overrideDate ?? parsedDate
    }

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

    func loadPickerData() {
        do {
            accounts = try bankAccountRepository.fetchBankAccounts(userId: userId)
            categories = try categoryRepository.fetchAll(userId: userId)
            hashtags = try hashtagRepository.fetchAll(userId: userId)
            if let settings = try userSettingsRepository.fetchSettings(userId: userId) {
                mainCurrency = settings.mainCurrency
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func parseCommand() {
        // Use the basic parser for amount and date only
        let parsed = parser.parse(commandText)
        parsedAmountCents = parsed.amountCents
        parsedDate = parsed.date

        // Context-aware tokenization: $account, @category, #hashtag, /person
        // all support multi-word names by greedily consuming words while they
        // prefix-match a known name.
        let tokens = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        let accountNames = accounts.map(\.name)
        let categoryNames = categories.map(\.name)
        let hashtagNames = hashtags.map(\.name)

        // Find the last amount token index so we can skip it (it's the actual amount)
        // but keep earlier number tokens as title text
        var lastAmountIndex: Int?
        for (index, token) in tokens.enumerated() {
            if parser.parseAmountPublic(token) != nil {
                lastAmountIndex = index
            }
        }

        // Each prefix type maps to its known names list
        // $ = account, @ = category, # = hashtag
        struct MatchState {
            let prefix: String          // "$", "@", "#"
            var words: [String]         // accumulated words (without prefix)
            var bestMatch: String?      // best exact match so far
            let knownNames: [String]
        }

        var titleParts: [String] = []
        var resolvedAccount: String?
        var resolvedCategory: String?
        var resolvedHashtags: [String] = []
        var activeMatch: MatchState?

        func finalizeMatch(_ state: MatchState) {
            if let best = state.bestMatch {
                // We found an exact match — leftover words go to title
                let matchedWordCount = best.components(separatedBy: " ").count
                let leftover = Array(state.words.dropFirst(matchedWordCount))
                titleParts.append(contentsOf: leftover)

                switch state.prefix {
                case "$": resolvedAccount = best
                case "@": resolvedCategory = best
                case "#": resolvedHashtags.append(best)
                default: break
                }
            } else {
                // No exact match — dump all words to title
                titleParts.append(contentsOf: state.words)
            }
        }

        func finalizeMatchInProgress(_ state: MatchState) {
            let candidate = state.words.joined(separator: " ")
            let hasPrefix = state.knownNames.contains {
                $0.lowercased().hasPrefix(candidate.lowercased())
            }

            if let best = state.bestMatch {
                // Had an exact match, maybe more words accumulated after
                let matchedWordCount = best.components(separatedBy: " ").count
                if state.words.count > matchedWordCount {
                    let leftover = Array(state.words.dropFirst(matchedWordCount))
                    titleParts.append(contentsOf: leftover)
                }
                switch state.prefix {
                case "$": resolvedAccount = best
                case "@": resolvedCategory = best
                case "#": resolvedHashtags.append(best)
                default: break
                }
            } else if hasPrefix {
                // Still a valid prefix — show as in-progress
                switch state.prefix {
                case "$": resolvedAccount = candidate
                case "@": resolvedCategory = candidate
                case "#": resolvedHashtags.append(candidate)
                default: break
                }
            } else {
                // No match — dump to title
                titleParts.append(contentsOf: state.words)
            }
        }

        for (tokenIndex, token) in tokens.enumerated() {
            // Skip the last amount token — it's the actual amount (handled by basic parser)
            if tokenIndex == lastAmountIndex {
                continue
            }

            // If we're in matching mode, try to extend the match
            if var state = activeMatch {
                state.words.append(token)
                let candidate = state.words.joined(separator: " ")

                let hasPrefix = state.knownNames.contains {
                    $0.lowercased().hasPrefix(candidate.lowercased())
                }
                let exactMatch = state.knownNames.first {
                    $0.caseInsensitiveCompare(candidate) == .orderedSame
                }

                if exactMatch != nil {
                    state.bestMatch = exactMatch
                    activeMatch = state // keep going, might be longer match
                } else if hasPrefix {
                    activeMatch = state // still matching
                } else {
                    // No prefix match — finalize current match
                    finalizeMatch(state)
                    activeMatch = nil
                }
                continue
            }

            // Check for prefix tokens that start matching mode
            if token.hasPrefix("$") && token.count > 1 {
                let firstWord = String(token.dropFirst())
                var state = MatchState(prefix: "$", words: [firstWord], bestMatch: nil, knownNames: accountNames)
                let exactMatch = accountNames.first { $0.caseInsensitiveCompare(firstWord) == .orderedSame }
                if exactMatch != nil { state.bestMatch = exactMatch }
                // Only enter matching mode if there's a possible prefix match
                let hasPrefix = accountNames.contains { $0.lowercased().hasPrefix(firstWord.lowercased()) }
                if hasPrefix || exactMatch != nil {
                    activeMatch = state
                } else {
                    titleParts.append(firstWord) // no account starts with this
                }
                continue
            }

            if token.hasPrefix("@") && token.count > 1 {
                let firstWord = String(token.dropFirst())
                var state = MatchState(prefix: "@", words: [firstWord], bestMatch: nil, knownNames: categoryNames)
                let exactMatch = categoryNames.first { $0.caseInsensitiveCompare(firstWord) == .orderedSame }
                if exactMatch != nil { state.bestMatch = exactMatch }
                let hasPrefix = categoryNames.contains { $0.lowercased().hasPrefix(firstWord.lowercased()) }
                if hasPrefix || exactMatch != nil {
                    activeMatch = state
                } else {
                    // Unknown category — still capture it for auto-creation
                    resolvedCategory = firstWord
                }
                continue
            }

            if token.hasPrefix("#") && token.count > 1 {
                let firstWord = String(token.dropFirst())
                var state = MatchState(prefix: "#", words: [firstWord], bestMatch: nil, knownNames: hashtagNames)
                let exactMatch = hashtagNames.first { $0.caseInsensitiveCompare(firstWord) == .orderedSame }
                if exactMatch != nil { state.bestMatch = exactMatch }
                let hasPrefix = hashtagNames.contains { $0.lowercased().hasPrefix(firstWord.lowercased()) }
                if hasPrefix || exactMatch != nil {
                    activeMatch = state
                } else {
                    // Unknown hashtag — still capture it for auto-creation
                    resolvedHashtags.append(firstWord)
                }
                continue
            }

            // Amount and date keywords are handled by the basic parser — skip them
            if parser.isSpecialToken(token) {
                continue
            }

            titleParts.append(token)
        }

        // Finalize any in-progress match at end of input
        if let state = activeMatch {
            finalizeMatchInProgress(state)
            activeMatch = nil
        }

        parsedAccountName = resolvedAccount
        parsedCategoryName = resolvedCategory
        parsedHashtags = resolvedHashtags
        parsedTitle = titleParts.isEmpty ? nil : titleParts.joined(separator: " ")
    }

    func submit() {
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        parseCommand()

        do {
            // Resolve account
            let accountId: UUID?
            if let name = parsedAccountName {
                guard let account = try bankAccountRepository.fetchByName(userId: userId, name: name) else {
                    errorMessage = "Account '\(name)' not found. Create it in Settings first."
                    return
                }
                accountId = account.id
            } else {
                accountId = overrideAccountId
            }

            // Resolve or create category
            var categoryId: UUID? = overrideCategoryId
            if categoryId == nil, let name = parsedCategoryName {
                if let existing = try categoryRepository.fetchByName(userId: userId, name: name) {
                    categoryId = existing.id
                } else {
                    let newCategory = ExpenseCategory(
                        userId: userId,
                        name: name,
                        categoryType: .expense,
                        color: TransactionDescriptionService.defaultCategoryColor
                    )
                    try categoryRepository.create(newCategory)
                    categories.append(newCategory)
                    categoryId = newCategory.id
                }
            }

            // Resolve or create hashtags
            var hashtagIds: [UUID] = []
            for name in parsedHashtags {
                if let existing = try hashtagRepository.fetchByName(userId: userId, name: name) {
                    hashtagIds.append(existing.id)
                } else {
                    let newHashtag = ExpenseHashtag(userId: userId, name: name)
                    try hashtagRepository.create(newHashtag)
                    hashtags.append(newHashtag)
                    hashtagIds.append(newHashtag.id)
                }
            }

            let resolvedDate = self.resolvedDate
            let title = parsedTitle ?? TransactionDescriptionService.untitledPlaceholder
            let amount = parsedAmountCents

            // Determine: ledger or inbox?
            if let amount, let resolvedDate, let accountId, let categoryId,
               title != TransactionDescriptionService.untitledPlaceholder, resolvedDate <= Date() {
                let transaction = ExpenseTransaction(
                    userId: userId,
                    title: title,
                    amountCents: amount,
                    date: resolvedDate,
                    accountId: accountId,
                    categoryId: categoryId,
                    sourceText: commandText
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
                let inbox = ExpenseTransactionInbox(
                    userId: userId,
                    title: title,
                    amountCents: amount,
                    date: resolvedDate,
                    accountId: accountId,
                    categoryId: categoryId,
                    sourceText: commandText
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Suggestions

    var categorySuggestions: [String] {
        guard let name = parsedCategoryName, !name.isEmpty else { return [] }
        let query = name.lowercased()
        return categories.map(\.name).filter { $0.lowercased().contains(query) }
    }

    var accountSuggestions: [String] {
        guard let name = parsedAccountName, !name.isEmpty else { return [] }
        let query = name.lowercased()
        return accounts.map(\.name).filter { $0.lowercased().contains(query) }
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
