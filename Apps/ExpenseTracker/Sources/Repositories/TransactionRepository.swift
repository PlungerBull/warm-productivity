import Foundation
import SwiftData
import SharedModels

@MainActor
final class TransactionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Balance Trigger (mirrors update_bank_account_balance)

    /// Adjusts the owning account's currentBalanceCents by delta.
    /// Mirrors the Supabase trigger: `update_bank_account_balance()`.
    private func adjustAccountBalance(accountId: UUID, delta: Int64) throws {
        let descriptor = FetchDescriptor<ExpenseBankAccount>(
            predicate: #Predicate { $0.id == accountId }
        )
        guard let account = try modelContext.fetch(descriptor).first else { return }
        account.currentBalanceCents += delta
        account.markUpdated()
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
        // Validate exchange rate > 0
        guard transaction.exchangeRate > 0 else {
            throw ConstraintError.invalidValue("Exchange rate must be greater than 0")
        }
        computeHomeCents(for: transaction)
        modelContext.insert(transaction)
        // Balance trigger: new active transaction → add amount to account
        if transaction.deletedAt == nil {
            try adjustAccountBalance(accountId: transaction.accountId, delta: transaction.amountCents)
        }
        try modelContext.save()
    }

    /// Update a ledger transaction. Caller must pass the old amount and account
    /// so the balance trigger can compute the delta correctly.
    func update(_ transaction: ExpenseTransaction, oldAmountCents: Int64, oldAccountId: UUID) throws {
        // Validate exchange rate > 0
        guard transaction.exchangeRate > 0 else {
            throw ConstraintError.invalidValue("Exchange rate must be greater than 0")
        }
        computeHomeCents(for: transaction)
        transaction.markUpdated()

        // Balance trigger: adjust for amount/account changes
        if transaction.deletedAt == nil {
            if transaction.accountId == oldAccountId {
                // Same account — adjust by delta
                let delta = transaction.amountCents - oldAmountCents
                if delta != 0 {
                    try adjustAccountBalance(accountId: transaction.accountId, delta: delta)
                }
            } else {
                // Account changed — subtract from old, add to new
                try adjustAccountBalance(accountId: oldAccountId, delta: -oldAmountCents)
                try adjustAccountBalance(accountId: transaction.accountId, delta: transaction.amountCents)
            }
        }

        try modelContext.save()
    }

    /// Computes amountHomeCents from amountCents * exchangeRate using Decimal arithmetic.
    /// Sets nil when exchangeRate is 1.0 (same currency, no conversion needed).
    private func computeHomeCents(for transaction: ExpenseTransaction) {
        if transaction.exchangeRate != 1.0 {
            let cents = Decimal(transaction.amountCents)
            let result = cents * transaction.exchangeRate
            transaction.amountHomeCents = NSDecimalNumber(decimal: result).int64Value
        } else {
            transaction.amountHomeCents = nil
        }
    }

    func softDelete(id: UUID) throws {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate { $0.id == id }
        )
        guard let transaction = try modelContext.fetch(descriptor).first else { return }
        // Balance trigger: active → deleted, subtract amount from account
        if transaction.deletedAt == nil {
            try adjustAccountBalance(accountId: transaction.accountId, delta: -transaction.amountCents)
        }
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
