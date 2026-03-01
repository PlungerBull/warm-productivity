import Foundation
import SwiftData

@Model
public final class TodoTask {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var title: String
    public var dueDate: Date?
    public var priority: Int
    public var isCompleted: Bool
    public var completedAt: Date?
    public var isRecurring: Bool
    public var parentTaskId: UUID?
    public var subtaskMode: SubtaskMode?
    public var categoryId: UUID?
    public var createdBy: UUID?
    public var assignedTo: UUID?
    public var sortOrder: Int
    public var hasFinancialData: Bool
    public var linkedInboxId: UUID?
    public var streakFrequency: StreakFrequency?
    public var streakGoalType: StreakGoalType?
    public var streakGoalValue: Int?
    public var streakRecordingMethod: StreakRecordingMethod?
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        title: String = "UNTITLED",
        dueDate: Date? = nil,
        priority: Int = 0,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isRecurring: Bool = false,
        parentTaskId: UUID? = nil,
        subtaskMode: SubtaskMode? = nil,
        categoryId: UUID? = nil,
        createdBy: UUID? = nil,
        assignedTo: UUID? = nil,
        sortOrder: Int = 0,
        hasFinancialData: Bool = false,
        linkedInboxId: UUID? = nil,
        streakFrequency: StreakFrequency? = nil,
        streakGoalType: StreakGoalType? = nil,
        streakGoalValue: Int? = nil,
        streakRecordingMethod: StreakRecordingMethod? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isRecurring = isRecurring
        self.parentTaskId = parentTaskId
        self.subtaskMode = subtaskMode
        self.categoryId = categoryId
        self.createdBy = createdBy
        self.assignedTo = assignedTo
        self.sortOrder = sortOrder
        self.hasFinancialData = hasFinancialData
        self.linkedInboxId = linkedInboxId
        self.streakFrequency = streakFrequency
        self.streakGoalType = streakGoalType
        self.streakGoalValue = streakGoalValue
        self.streakRecordingMethod = streakRecordingMethod
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
