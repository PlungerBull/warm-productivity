import Foundation
import SwiftData
import SharedModels

@MainActor
final class HashtagRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll(userId: UUID) throws -> [ExpenseHashtag] {
        let descriptor = FetchDescriptor<ExpenseHashtag>(
            predicate: #Predicate { $0.userId == userId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByName(userId: UUID, name: String) throws -> ExpenseHashtag? {
        let descriptor = FetchDescriptor<ExpenseHashtag>(
            predicate: #Predicate {
                $0.userId == userId && $0.name == name && $0.deletedAt == nil
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    func create(_ hashtag: ExpenseHashtag) throws {
        // UNIQUE: uq_expense_hashtags_user_name
        if try fetchByName(userId: hashtag.userId, name: hashtag.name) != nil {
            throw ConstraintError.duplicate("Hashtag '\(hashtag.name)' already exists")
        }
        modelContext.insert(hashtag)
        try modelContext.save()
    }

    func update(id: UUID, name: String) throws {
        guard let hashtag = try fetchById(id) else { return }
        hashtag.name = name
        hashtag.markUpdated()
        try modelContext.save()
    }

    func updateSortOrder(id: UUID, sortOrder: Int) throws {
        guard let hashtag = try fetchById(id) else { return }
        hashtag.sortOrder = sortOrder
        hashtag.markUpdated()
        try modelContext.save()
    }

    func softDelete(id: UUID) throws {
        guard let hashtag = try fetchById(id) else { return }
        hashtag.markDeleted()
        try modelContext.save()
    }

    func fetchById(_ id: UUID) throws -> ExpenseHashtag? {
        let descriptor = FetchDescriptor<ExpenseHashtag>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        return try modelContext.fetch(descriptor).first
    }
}
