import Foundation
import SwiftData

@Model
public final class ExpenseCategory {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var name: String
    public var categoryType: ExpenseCategoryType
    public var color: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        categoryType: ExpenseCategoryType = .expense,
        color: String,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.categoryType = categoryType
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
