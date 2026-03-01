import Foundation
import SwiftData

@Model
public final class TodoRecurrenceRule {
    @Attribute(.unique) public var id: UUID
    public var taskId: UUID
    public var userId: UUID
    public var pattern: RecurrencePattern
    public var interval: Int
    public var daysOfWeek: [Int]?
    public var dayOfMonth: Int?
    public var weekOfMonth: Int?
    public var anchor: RecurrenceAnchor
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        userId: UUID,
        pattern: RecurrencePattern,
        interval: Int = 1,
        daysOfWeek: [Int]? = nil,
        dayOfMonth: Int? = nil,
        weekOfMonth: Int? = nil,
        anchor: RecurrenceAnchor = .fixed,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.userId = userId
        self.pattern = pattern
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.dayOfMonth = dayOfMonth
        self.weekOfMonth = weekOfMonth
        self.anchor = anchor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
