import Foundation
import SwiftData

@Model
public final class TransactionShare {
    @Attribute(.unique) public var id: UUID
    public var transactionId: UUID
    public var userId: UUID
    public var categoryId: UUID?
    public var originatorConfirmed: Bool
    public var receiverConfirmed: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        transactionId: UUID,
        userId: UUID,
        categoryId: UUID? = nil,
        originatorConfirmed: Bool = false,
        receiverConfirmed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.transactionId = transactionId
        self.userId = userId
        self.categoryId = categoryId
        self.originatorConfirmed = originatorConfirmed
        self.receiverConfirmed = receiverConfirmed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
