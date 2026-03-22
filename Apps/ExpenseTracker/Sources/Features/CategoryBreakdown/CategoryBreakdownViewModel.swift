import Foundation
import SharedModels
import SharedUtilities

struct CategorySpendItem: Identifiable {
    let id: UUID
    let name: String
    let color: String
    let spendCents: Int64
    let transactionCount: Int
    let percentage: Double
}

@MainActor
@Observable
final class CategoryBreakdownViewModel {
    private let transactionRepository: TransactionRepository
    private let categoryRepository: CategoryRepository
    private let userSettingsRepository: UserSettingsRepository
    private let userId: UUID

    var items: [CategorySpendItem] = []
    var totalSpendCents: Int64 = 0
    var totalIncomeCents: Int64 = 0
    private(set) var currencyFormatter = CurrencyFormatter()

    // Period selection
    var selectedPeriod: BreakdownPeriod = .currentMonth

    enum BreakdownPeriod: String, CaseIterable {
        case currentMonth = "This Month"
        case lastMonth = "Last Month"
        case last3Months = "3 Months"
        case allTime = "All Time"
    }

    init(
        transactionRepository: TransactionRepository,
        categoryRepository: CategoryRepository,
        userSettingsRepository: UserSettingsRepository,
        userId: UUID
    ) {
        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.userSettingsRepository = userSettingsRepository
        self.userId = userId
    }

    func load() {
        do {
            if let settings = try userSettingsRepository.fetchSettings(userId: userId) {
                currencyFormatter = CurrencyFormatter(currencyCode: settings.mainCurrency)
            }

            let categories = try categoryRepository.fetchAll(userId: userId)
            let allTransactions = try transactionRepository.fetchAll(userId: userId)

            // Filter by period
            let (start, end) = dateRange(for: selectedPeriod)
            let filtered = allTransactions.filter { tx in
                if let start { guard tx.date >= start else { return false } }
                if let end { guard tx.date < end else { return false } }
                return true
            }

            // Separate income and expenses
            let expenses = filtered.filter { $0.amountCents < 0 }
            let income = filtered.filter { $0.amountCents >= 0 }

            totalSpendCents = expenses.reduce(0) { $0 + ($1.amountHomeCents ?? $1.amountCents) }
            totalIncomeCents = income.reduce(0) { $0 + ($1.amountHomeCents ?? $1.amountCents) }

            // Group expenses by category
            let grouped = Dictionary(grouping: expenses) { $0.categoryId }
            let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

            let totalAbsSpend = abs(totalSpendCents)

            var result: [CategorySpendItem] = []
            for (categoryId, transactions) in grouped {
                let category = categoryMap[categoryId]
                let spend = transactions.reduce(0) { $0 + ($1.amountHomeCents ?? $1.amountCents) }
                let percentage = totalAbsSpend > 0 ? Double(abs(spend)) / Double(totalAbsSpend) * 100 : 0

                result.append(CategorySpendItem(
                    id: categoryId,
                    name: category?.name ?? "Unknown",
                    color: category?.color ?? TransactionDescriptionService.fallbackCategoryColor,
                    spendCents: spend,
                    transactionCount: transactions.count,
                    percentage: percentage
                ))
            }

            // Sort by spend (most negative first = highest expense)
            items = result.sorted { abs($0.spendCents) > abs($1.spendCents) }
        } catch {
            items = []
        }
    }

    private func dateRange(for period: BreakdownPeriod) -> (Date?, Date?) {
        let calendar = Calendar.current
        let now = Date()

        guard let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return (nil, nil)
        }

        switch period {
        case .currentMonth:
            let end = calendar.date(byAdding: .month, value: 1, to: thisMonth)
            return (thisMonth, end)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonth)
            return (start, thisMonth)
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -3, to: thisMonth)
            let end = calendar.date(byAdding: .month, value: 1, to: thisMonth)
            return (start, end)
        case .allTime:
            return (nil, nil)
        }
    }
}
