import Foundation
import SwiftData

@Model
public final class ExpenseBudget {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var categoryId: UUID
    public var amountCents: Int64
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        categoryId: UUID,
        amountCents: Int64,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.categoryId = categoryId
        self.amountCents = amountCents
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
