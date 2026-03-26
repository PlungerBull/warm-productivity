import Foundation
import SwiftData
import SharedModels

@MainActor
final class BankAccountRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Cascade Helpers

    /// Soft-delete all transactions for an account (CASCADE behavior).
    /// Also adjusts the account balance for each active transaction being deleted.
    private func cascadeDeleteTransactions(accountId: UUID, userId: UUID) throws {
        let descriptor = FetchDescriptor<ExpenseTransaction>(
            predicate: #Predicate {
                $0.accountId == accountId && $0.userId == userId && $0.deletedAt == nil
            }
        )
        let transactions = try modelContext.fetch(descriptor)
        let entityLinkRepo = EntityLinkRepository(modelContext: modelContext)
        for transaction in transactions {
            transaction.markDeleted()
            // CASCADE: soft-delete entity_links for each cascaded transaction
            try entityLinkRepo.softDeleteAllReferences(entityType: .expenseLedger, entityId: transaction.id)
        }
    }

    func fetchAll(userId: UUID) throws -> [ExpenseBankAccount] {
        let descriptor = FetchDescriptor<ExpenseBankAccount>(
            predicate: #Predicate { $0.userId == userId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> ExpenseBankAccount? {
        let descriptor = FetchDescriptor<ExpenseBankAccount>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchByName(userId: UUID, name: String) throws -> ExpenseBankAccount? {
        let descriptor = FetchDescriptor<ExpenseBankAccount>(
            predicate: #Predicate {
                $0.userId == userId && $0.name == name && $0.deletedAt == nil
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    func create(_ account: ExpenseBankAccount) throws {
        // UNIQUE: uq_expense_bank_accounts_user_name_currency
        let name = account.name
        let currency = account.currencyCode
        let userId = account.userId
        let descriptor = FetchDescriptor<ExpenseBankAccount>(
            predicate: #Predicate {
                $0.userId == userId && $0.name == name && $0.currencyCode == currency && $0.deletedAt == nil
            }
        )
        if try !modelContext.fetch(descriptor).isEmpty {
            throw ConstraintError.duplicate("Account '\(name)' (\(currency)) already exists")
        }
        modelContext.insert(account)
        try modelContext.save()
    }

    func update(id: UUID, name: String? = nil, color: String? = nil) throws {
        guard let account = try fetchById(id) else { return }
        if let name { account.name = name }
        if let color { account.color = color }
        account.markUpdated()
        try modelContext.save()
    }

    func updateSortOrder(id: UUID, sortOrder: Int) throws {
        guard let account = try fetchById(id) else { return }
        account.sortOrder = sortOrder
        account.markUpdated()
        try modelContext.save()
    }

    func archive(id: UUID) throws {
        guard let account = try fetchById(id) else { return }
        account.isArchived = true
        account.markUpdated()
        try modelContext.save()
    }

    /// Soft-delete an account and CASCADE soft-delete its transactions.
    /// Also SET NULL on inbox items referencing this account.
    func softDelete(id: UUID) throws {
        guard let account = try fetchById(id) else { return }
        let accountId = account.id
        let userId = account.userId
        // CASCADE: soft-delete all ledger transactions for this account
        try cascadeDeleteTransactions(accountId: accountId, userId: userId)
        // SET NULL: nullify accountId on inbox items referencing this account
        let inboxDescriptor = FetchDescriptor<ExpenseTransactionInbox>(
            predicate: #Predicate {
                $0.accountId == accountId && $0.userId == userId && $0.deletedAt == nil
            }
        )
        for item in try modelContext.fetch(inboxDescriptor) {
            item.accountId = nil
            item.markUpdated()
        }
        account.currentBalanceCents = 0
        account.markDeleted()
        try modelContext.save()
    }

    func hasAnyAccounts(userId: UUID) throws -> Bool {
        let descriptor = FetchDescriptor<ExpenseBankAccount>(
            predicate: #Predicate { $0.userId == userId && $0.deletedAt == nil }
        )
        return try !modelContext.fetch(descriptor).isEmpty
    }

    /// Fetch bank accounts that are not person accounts (real bank accounts only).
    func fetchBankAccounts(userId: UUID) throws -> [ExpenseBankAccount] {
        let descriptor = FetchDescriptor<ExpenseBankAccount>(
            predicate: #Predicate {
                $0.userId == userId && $0.isPerson == false && $0.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }
}
