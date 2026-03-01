import Foundation
import SwiftData

@Model
public final class ExpenseBankAccount {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var name: String
    public var currencyCode: String
    public var isPerson: Bool
    public var linkedUserId: UUID?
    public var color: String
    public var isVisible: Bool
    public var currentBalanceCents: Int64
    public var isArchived: Bool
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
        currencyCode: String = "USD",
        isPerson: Bool = false,
        linkedUserId: UUID? = nil,
        color: String = "#3b82f6",
        isVisible: Bool = true,
        currentBalanceCents: Int64 = 0,
        isArchived: Bool = false,
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
        self.currencyCode = currencyCode
        self.isPerson = isPerson
        self.linkedUserId = linkedUserId
        self.color = color
        self.isVisible = isVisible
        self.currentBalanceCents = currentBalanceCents
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
