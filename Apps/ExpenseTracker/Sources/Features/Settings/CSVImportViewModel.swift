import Foundation
import SharedModels
import UniformTypeIdentifiers

@MainActor
@Observable
final class CSVImportViewModel {
    private let transactionRepository: TransactionRepository
    private let categoryRepository: CategoryRepository
    private let bankAccountRepository: BankAccountRepository
    private let hashtagRepository: HashtagRepository
    private let transactionHashtagRepository: TransactionHashtagRepository
    private let noteEntryRepository: NoteEntryRepository
    private let entityLinkRepository: EntityLinkRepository
    private let userSettingsRepository: UserSettingsRepository
    private let userId: UUID

    var isImporting: Bool = false
    var showFilePicker: Bool = false
    var showSummary: Bool = false
    var errorMessage: String?

    // Import results
    var importedCount: Int = 0
    var duplicateCount: Int = 0
    var errorCount: Int = 0
    var errorDetails: [String] = []

    init(
        transactionRepository: TransactionRepository,
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
        self.categoryRepository = categoryRepository
        self.bankAccountRepository = bankAccountRepository
        self.hashtagRepository = hashtagRepository
        self.transactionHashtagRepository = transactionHashtagRepository
        self.noteEntryRepository = noteEntryRepository
        self.entityLinkRepository = entityLinkRepository
        self.userSettingsRepository = userSettingsRepository
        self.userId = userId
    }

    func importCSV(url: URL) {
        isImporting = true
        importedCount = 0
        duplicateCount = 0
        errorCount = 0
        errorDetails = []

        defer { isImporting = false }

        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = parseCSV(content)

            guard let headerRow = rows.first else {
                errorMessage = "CSV file is empty."
                return
            }

            let headers = headerRow.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

            // Find required column indices
            guard let titleIdx = headers.firstIndex(of: "title"),
                  let amountIdx = headers.firstIndex(of: "amount"),
                  let accountIdx = headers.firstIndex(of: "account"),
                  let categoryIdx = headers.firstIndex(of: "category"),
                  let dateIdx = headers.firstIndex(of: "date") else {
                errorMessage = "Missing required columns. Expected: title, amount, account, category, date"
                return
            }

            // Optional columns
            let currencyIdx = headers.firstIndex(of: "currency")
            let hashtagsIdx = headers.firstIndex(of: "hashtags")
            let exchangeRateIdx = headers.firstIndex(of: "exchange_rate")
            let notesIdx = headers.firstIndex(of: "notes")

            let settings = try userSettingsRepository.fetchSettings(userId: userId)
            let defaultCurrency = settings?.mainCurrency ?? "USD"

            // Load existing transactions for duplicate detection
            let existing = try transactionRepository.fetchAll(userId: userId)
            let existingKeys = Set(existing.map { duplicateKey(title: $0.title, amount: $0.amountCents, date: $0.date, accountId: $0.accountId) })

            // Process data rows
            for (rowIndex, row) in rows.dropFirst().enumerated() {
                let rowNum = rowIndex + 2 // 1-indexed, skip header

                guard row.count > max(titleIdx, amountIdx, accountIdx, categoryIdx, dateIdx) else {
                    errorCount += 1
                    errorDetails.append("Row \(rowNum): Not enough columns")
                    continue
                }

                let title = row[titleIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                let amountStr = row[amountIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                let accountName = row[accountIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                let categoryName = row[categoryIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                let dateStr = row[dateIdx].trimmingCharacters(in: .whitespacesAndNewlines)

                // Validate required fields
                guard !title.isEmpty else {
                    errorCount += 1
                    errorDetails.append("Row \(rowNum): Missing title")
                    continue
                }

                guard let amountValue = Double(amountStr) else {
                    errorCount += 1
                    errorDetails.append("Row \(rowNum): Invalid amount '\(amountStr)'")
                    continue
                }
                let amountCents = Int64(round(amountValue * 100))

                guard let date = parseDate(dateStr) else {
                    errorCount += 1
                    errorDetails.append("Row \(rowNum): Invalid date '\(dateStr)'")
                    continue
                }

                // Resolve or create account
                let account: ExpenseBankAccount
                do {
                    if let existing = try bankAccountRepository.fetchByName(userId: userId, name: accountName) {
                        account = existing
                    } else {
                        let currency = currencyIdx.flatMap { idx in
                            idx < row.count ? row[idx].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                        } ?? defaultCurrency
                        let newAccount = ExpenseBankAccount(
                            userId: userId,
                            name: accountName,
                            currencyCode: currency.isEmpty ? defaultCurrency : currency
                        )
                        try bankAccountRepository.create(newAccount)
                        account = newAccount
                    }
                } catch {
                    errorCount += 1
                    errorDetails.append("Row \(rowNum): Failed to resolve account '\(accountName)'")
                    continue
                }

                // Resolve or create category
                let categoryId: UUID
                do {
                    if let existing = try categoryRepository.fetchByName(userId: userId, name: categoryName) {
                        categoryId = existing.id
                    } else {
                        let newCategory = ExpenseCategory(
                            userId: userId,
                            name: categoryName,
                            categoryType: amountCents < 0 ? .expense : .income,
                            color: TransactionDescriptionService.defaultCategoryColor
                        )
                        try categoryRepository.create(newCategory)
                        categoryId = newCategory.id
                    }
                } catch {
                    errorCount += 1
                    errorDetails.append("Row \(rowNum): Failed to resolve category '\(categoryName)'")
                    continue
                }

                // Duplicate check
                let key = duplicateKey(title: title, amount: amountCents, date: date, accountId: account.id)
                if existingKeys.contains(key) {
                    duplicateCount += 1
                    continue
                }

                // Exchange rate
                var exchangeRate: Decimal = 1.0
                if let erIdx = exchangeRateIdx, erIdx < row.count {
                    let erStr = row[erIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let er = Decimal(string: erStr), er > 0 {
                        exchangeRate = er
                    }
                }

                // Create transaction
                let transaction = ExpenseTransaction(
                    userId: userId,
                    title: title,
                    amountCents: amountCents,
                    date: date,
                    accountId: account.id,
                    categoryId: categoryId,
                    exchangeRate: exchangeRate,
                    sourceText: "csv_import"
                )

                do {
                    try transactionRepository.create(transaction)
                } catch {
                    errorCount += 1
                    errorDetails.append("Row \(rowNum): Failed to create transaction")
                    continue
                }

                // Hashtags
                if let hIdx = hashtagsIdx, hIdx < row.count {
                    let hashtagStr = row[hIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !hashtagStr.isEmpty {
                        let tagNames = hashtagStr.components(separatedBy: ",").map {
                            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                        }.filter { !$0.isEmpty }

                        for tagName in tagNames {
                            do {
                                let hashtag: ExpenseHashtag
                                if let existing = try hashtagRepository.fetchByName(userId: userId, name: tagName) {
                                    hashtag = existing
                                } else {
                                    let newHashtag = ExpenseHashtag(userId: userId, name: tagName)
                                    try hashtagRepository.create(newHashtag)
                                    hashtag = newHashtag
                                }
                                try transactionHashtagRepository.link(
                                    transactionId: transaction.id,
                                    source: .ledger,
                                    hashtagId: hashtag.id,
                                    userId: userId
                                )
                            } catch {
                                errorCount += 1
                                errorDetails.append("Row \(rowNum): Failed to link hashtag '\(tagName)'")
                            }
                        }
                    }
                }

                // Notes
                if let nIdx = notesIdx, nIdx < row.count {
                    let notes = row[nIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !notes.isEmpty {
                        do {
                            try TransactionDescriptionService.createLinkedNote(
                                userId: userId,
                                sourceType: .expenseLedger,
                                sourceId: transaction.id,
                                content: notes,
                                noteEntryRepository: noteEntryRepository,
                                entityLinkRepository: entityLinkRepository
                            )
                        } catch {
                            errorCount += 1
                            errorDetails.append("Row \(rowNum): Failed to save notes")
                        }
                    }
                }

                importedCount += 1
            }

            showSummary = true
        } catch {
            errorMessage = "Failed to read file: \(error.localizedDescription)"
        }
    }

    // MARK: - CSV Parsing

    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in content {
            if inQuotes {
                if char == "\"" {
                    inQuotes = false
                } else {
                    currentField.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n", "\r\n":
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                default:
                    currentField.append(char)
                }
            }
        }

        // Last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = {
            let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd", "MM-dd-yyyy"]
            return formats.map { format in
                let f = DateFormatter()
                f.dateFormat = format
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }
        }()

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private func duplicateKey(title: String, amount: Int64, date: Date, accountId: UUID) -> String {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return "\(title.lowercased())|\(amount)|\(day.timeIntervalSince1970)|\(accountId)"
    }

    func reset() {
        importedCount = 0
        duplicateCount = 0
        errorCount = 0
        errorDetails = []
        showSummary = false
        errorMessage = nil
    }
}
