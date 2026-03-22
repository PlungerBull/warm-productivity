import Foundation
import SwiftData
import SharedModels

@MainActor
final class TransactionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll(userId: UUID) throws -> [ExpenseTransaction] {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate { $0.userId == userId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> ExpenseTransaction? {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        return try modelContext.fetch(descriptor).first
    }

    func create(_ transaction: ExpenseTransaction) throws {
        computeHomeCents(for: transaction)
        modelContext.insert(transaction)
        try modelContext.save()
    }

    func update(_ transaction: ExpenseTransaction) throws {
        computeHomeCents(for: transaction)
        transaction.markUpdated()
        try modelContext.save()
    }

    /// Computes amountHomeCents from amountCents * exchangeRate.
    /// Sets nil when exchangeRate is 1.0 (same currency, no conversion needed).
    private func computeHomeCents(for transaction: ExpenseTransaction) {
        if transaction.exchangeRate != 1.0 {
            let rate = NSDecimalNumber(decimal: transaction.exchangeRate).doubleValue
            transaction.amountHomeCents = Int64(Double(transaction.amountCents) * rate)
        } else {
            transaction.amountHomeCents = nil
        }
    }

    func softDelete(id: UUID) throws {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate { $0.id == id }
        )
        guard let transaction = try modelContext.fetch(descriptor).first else { return }
        transaction.markDeleted()
        try modelContext.save()
    }

    // MARK: - Filtered Fetches (Ledger only)

    func fetchByAccount(userId: UUID, accountId: UUID) throws -> [ExpenseTransaction] {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate {
                $0.userId == userId && $0.accountId == accountId && $0.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByCategory(userId: UUID, categoryId: UUID) throws -> [ExpenseTransaction] {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate {
                $0.userId == userId && $0.categoryId == categoryId && $0.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch transactions by a set of transaction IDs (used for hashtag filtering).
    func fetchByIds(userId: UUID, ids: [UUID]) throws -> [ExpenseTransaction] {
        let transactions = try fetchAll(userId: userId)
        let idSet = Set(ids)
        return transactions.filter { idSet.contains($0.id) }
    }

    // MARK: - Aggregate Queries

    /// Sum of amountHomeCents (falling back to amountCents) for all non-deleted transactions in an account.
    func runningBalanceCents(userId: UUID, accountId: UUID) throws -> Int64 {
        let transactions = try fetchByAccount(userId: userId, accountId: accountId)
        return transactions.reduce(0) { $0 + ($1.amountHomeCents ?? $1.amountCents) }
    }

    /// Sum of amountHomeCents (falling back to amountCents) for non-deleted transactions in a category within the current calendar month.
    func currentMonthSpendCents(userId: UUID, categoryId: UUID) throws -> Int64 {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return 0
        }

        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate {
                $0.userId == userId
                    && $0.categoryId == categoryId
                    && $0.deletedAt == nil
                    && $0.date >= monthStart
                    && $0.date < monthEnd
            }
        )
        let transactions = try modelContext.fetch(descriptor)
        return transactions.reduce(0) { $0 + ($1.amountHomeCents ?? $1.amountCents) }
    }
}
