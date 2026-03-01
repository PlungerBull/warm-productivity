import Foundation
import SwiftData

@Model
public final class TodoTaskHashtag {
    @Attribute(.unique) public var id: UUID
    public var taskId: UUID
    public var hashtagId: UUID
    public var userId: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        hashtagId: UUID,
        userId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.hashtagId = hashtagId
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
