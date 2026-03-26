import Foundation
import SwiftData
import SharedModels

@MainActor
final class NoteEntryRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchById(_ id: UUID) throws -> NoteEntry? {
        let descriptor = FetchDescriptor<NoteEntry>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        return try modelContext.fetch(descriptor).first
    }

    func create(_ entry: NoteEntry) throws {
        // CHECK: chk_note_pinned_requires_notebook
        if entry.isPinned && entry.notebookId == nil {
            entry.isPinned = false
        }
        modelContext.insert(entry)
        try modelContext.save()
    }

    func update(id: UUID, content: String) throws {
        guard let entry = try fetchById(id) else { return }
        entry.content = content
        // CHECK: chk_note_pinned_requires_notebook
        if entry.isPinned && entry.notebookId == nil {
            entry.isPinned = false
        }
        entry.markUpdated()
        try modelContext.save()
    }

    func softDelete(id: UUID) throws {
        guard let entry = try fetchById(id) else { return }
        entry.markDeleted()
        // CASCADE: soft-delete all entity_links referencing this note
        let entityLinkRepo = EntityLinkRepository(modelContext: modelContext)
        try entityLinkRepo.softDeleteAllReferences(entityType: .note, entityId: id)
        try modelContext.save()
    }
}
