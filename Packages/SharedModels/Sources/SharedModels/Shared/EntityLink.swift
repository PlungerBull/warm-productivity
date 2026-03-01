import Foundation
import SwiftData

@Model
public final class EntityLink {
    @Attribute(.unique) public var id: UUID
    public var sourceType: EntitySourceType
    public var sourceId: UUID
    public var targetType: EntitySourceType
    public var targetId: UUID
    public var linkContext: EntityLinkContext
    public var userId: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        sourceType: EntitySourceType,
        sourceId: UUID,
        targetType: EntitySourceType,
        targetId: UUID,
        linkContext: EntityLinkContext,
        userId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.targetType = targetType
        self.targetId = targetId
        self.linkContext = linkContext
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
