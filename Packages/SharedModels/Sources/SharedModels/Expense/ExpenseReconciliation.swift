import Foundation
import SwiftData

@Model
public final class ExpenseReconciliation {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var accountId: UUID
    public var name: String
    public var dateStart: Date?
    public var dateEnd: Date?
    public var status: ReconciliationStatus
    public var beginningBalanceCents: Int64
    public var endingBalanceCents: Int64
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        accountId: UUID,
        name: String,
        dateStart: Date? = nil,
        dateEnd: Date? = nil,
        status: ReconciliationStatus = .draft,
        beginningBalanceCents: Int64 = 0,
        endingBalanceCents: Int64 = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.accountId = accountId
        self.name = name
        self.dateStart = dateStart
        self.dateEnd = dateEnd
        self.status = status
        self.beginningBalanceCents = beginningBalanceCents
        self.endingBalanceCents = endingBalanceCents
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
