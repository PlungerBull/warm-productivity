import Foundation
import SwiftData

@Model
public final class NoteEntry {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var title: String
    public var content: String?
    public var notebookId: UUID?
    public var isPinned: Bool
    public var noteDate: Date
    public var hiddenInNotesApp: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        title: String = "UNTITLED",
        content: String? = nil,
        notebookId: UUID? = nil,
        isPinned: Bool = false,
        noteDate: Date = Date(),
        hiddenInNotesApp: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.notebookId = notebookId
        self.isPinned = isPinned
        self.noteDate = noteDate
        self.hiddenInNotesApp = hiddenInNotesApp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
