import Foundation
import SwiftData
import SharedModels

@MainActor
final class InboxRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Fetch all non-deleted, non-recurring inbox items sorted by creation date (newest first).
    func fetchAll(userId: UUID) throws -> [ExpenseTransactionInbox] {
        let descriptor = FetchDescriptor<ExpenseTransactionInbox>(
            predicate: #Predicate {
                $0.userId == userId && $0.deletedAt == nil && $0.isRecurring == false
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> ExpenseTransactionInbox? {
        let descriptor = FetchDescriptor<ExpenseTransactionInbox>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Count of non-deleted, non-recurring inbox items.
    func count(userId: UUID) throws -> Int {
        let descriptor = FetchDescriptor<ExpenseTransactionInbox>(
            predicate: #Predicate {
                $0.userId == userId && $0.deletedAt == nil && $0.isRecurring == false
            }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func create(_ item: ExpenseTransactionInbox) throws {
        modelContext.insert(item)
        try modelContext.save()
    }

    func update(_ item: ExpenseTransactionInbox) throws {
        item.markUpdated()
        try modelContext.save()
    }

    func softDelete(id: UUID) throws {
        let descriptor = FetchDescriptor<ExpenseTransactionInbox>(
            predicate: #Predicate { $0.id == id }
        )
        guard let item = try modelContext.fetch(descriptor).first else { return }
        item.markDeleted()
        // CASCADE: soft-delete all entity_links referencing this inbox item
        let entityLinkRepo = EntityLinkRepository(modelContext: modelContext)
        try entityLinkRepo.softDeleteAllReferences(entityType: .expenseInbox, entityId: id)
        try modelContext.save()
    }
}
