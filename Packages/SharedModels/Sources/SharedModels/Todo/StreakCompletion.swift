import Foundation
import SwiftData

@Model
public final class StreakCompletion {
    @Attribute(.unique) public var id: UUID
    public var taskId: UUID
    public var userId: UUID
    public var date: Date
    public var value: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        userId: UUID,
        date: Date = Date(),
        value: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.userId = userId
        self.date = date
        self.value = value
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
