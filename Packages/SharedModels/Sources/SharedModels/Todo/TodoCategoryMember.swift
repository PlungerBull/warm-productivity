import Foundation
import SwiftData

@Model
public final class TodoCategoryMember {
    @Attribute(.unique) public var id: UUID
    public var categoryId: UUID
    public var userId: UUID
    public var invitedBy: UUID
    public var role: TodoMemberRole
    public var joinedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        categoryId: UUID,
        userId: UUID,
        invitedBy: UUID,
        role: TodoMemberRole = .member,
        joinedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.categoryId = categoryId
        self.userId = userId
        self.invitedBy = invitedBy
        self.role = role
        self.joinedAt = joinedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
