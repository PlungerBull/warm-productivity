import Foundation
import SwiftData

@Model
public final class ActivityLog {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var actionType: ActionType
    public var entityType: String
    public var entityId: UUID
    public var summaryText: String
    public var timestamp: Date
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        actionType: ActionType,
        entityType: String,
        entityId: UUID,
        summaryText: String,
        timestamp: Date = Date(),
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.actionType = actionType
        self.entityType = entityType
        self.entityId = entityId
        self.summaryText = summaryText
        self.timestamp = timestamp
        self.syncedAt = syncedAt
    }
}
