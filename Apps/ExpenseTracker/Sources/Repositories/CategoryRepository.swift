import Foundation
import SwiftData
import SharedModels

@MainActor
final class CategoryRepository {
    private let modelContext: ModelContext

    /// System category names that cannot be deleted or renamed.
    static let systemCategoryNames: Set<String> = ["Other", "Debt"]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll(userId: UUID) throws -> [ExpenseCategory] {
        let descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.userId == userId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByName(userId: UUID, name: String) throws -> ExpenseCategory? {
        let descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate {
                $0.userId == userId && $0.name == name && $0.deletedAt == nil
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchById(_ id: UUID) throws -> ExpenseCategory? {
        let descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Creates the @Other system category if it doesn't already exist.
    /// Returns the category (existing or newly created).
    func ensureOtherCategory(userId: UUID) throws -> ExpenseCategory {
        if let existing = try fetchByName(userId: userId, name: "Other") {
            return existing
        }
        let category = ExpenseCategory(
            userId: userId,
            name: "Other",
            categoryType: .expense,
            color: TransactionDescriptionService.fallbackCategoryColor
        )
        modelContext.insert(category)
        try modelContext.save()
        return category
    }

    func create(_ category: ExpenseCategory) throws {
        modelContext.insert(category)
        try modelContext.save()
    }

    func update(id: UUID, name: String? = nil, color: String? = nil) throws {
        guard let category = try fetchById(id) else { return }
        if Self.systemCategoryNames.contains(category.name) && name != nil {
            return // Refuse to rename system categories
        }
        if let name { category.name = name }
        if let color { category.color = color }
        category.markUpdated()
        try modelContext.save()
    }

    func updateSortOrder(id: UUID, sortOrder: Int) throws {
        guard let category = try fetchById(id) else { return }
        category.sortOrder = sortOrder
        category.markUpdated()
        try modelContext.save()
    }

    func softDelete(id: UUID) throws {
        guard let category = try fetchById(id) else { return }
        // Refuse to delete system categories
        if Self.systemCategoryNames.contains(category.name) { return }
        category.markDeleted()
        try modelContext.save()
    }
}
