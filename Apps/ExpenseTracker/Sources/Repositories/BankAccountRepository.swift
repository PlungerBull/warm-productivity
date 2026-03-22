import Foundation
import SwiftData
import SharedModels

@MainActor
final class BankAccountRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
