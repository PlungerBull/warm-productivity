import Foundation
import SharedModels

/// Consolidates the Universal Description Model pattern for expense transactions.
/// Creates/updates/loads NoteEntry + EntityLink pairs that serve as transaction descriptions.
@MainActor
enum TransactionDescriptionService {

    // MARK: - Constants

    static let noteTitle = "Expense Note"
    static let defaultCategoryColor = "#3b82f6"
    static let fallbackCategoryColor = "#78716c"
    static let untitledPlaceholder = "UNTITLED"

    // MARK: - Create

    /// Creates a NoteEntry + EntityLink pair for a transaction description.
    static func createLinkedNote(
        userId: UUID,
        sourceType: EntitySourceType,
        sourceId: UUID,
        content: String,
        noteEntryRepository: NoteEntryRepository,
        entityLinkRepository: EntityLinkRepository
    ) throws {
        let note = NoteEntry(
            userId: userId,
            title: noteTitle,
            content: content,
            hiddenInNotesApp: true
        )
        try noteEntryRepository.create(note)
        let link = EntityLink(
            sourceType: sourceType,
            sourceId: sourceId,
            targetType: .note,
            targetId: note.id,
            linkContext: .expenseNote,
            userId: userId
        )
        try entityLinkRepository.create(link)
    }

    // MARK: - Load

    /// Loads the description text for a transaction, if one exists.
    static func loadDescription(
        sourceType: EntitySourceType,
        sourceId: UUID,
        noteEntryRepository: NoteEntryRepository,
        entityLinkRepository: EntityLinkRepository
    ) throws -> String {
        if let noteId = try entityLinkRepository.fetchTargetId(
            sourceType: sourceType,
            sourceId: sourceId,
            targetType: .note,
            context: .expenseNote
        ),
           let note = try noteEntryRepository.fetchById(noteId) {
            return note.content ?? ""
        }
        return ""
    }

    // MARK: - Update or Create

    /// Updates an existing linked note, creates one if it doesn't exist,
    /// or soft-deletes if content is empty.
    static func saveDescription(
        userId: UUID,
        sourceType: EntitySourceType,
        sourceId: UUID,
        content: String,
        noteEntryRepository: NoteEntryRepository,
        entityLinkRepository: EntityLinkRepository
    ) throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let noteId = try entityLinkRepository.fetchTargetId(
            sourceType: sourceType,
            sourceId: sourceId,
            targetType: .note,
            context: .expenseNote
        ) {
            if trimmed.isEmpty {
                try noteEntryRepository.softDelete(id: noteId)
                try entityLinkRepository.softDelete(sourceType: sourceType, sourceId: sourceId)
            } else {
                try noteEntryRepository.update(id: noteId, content: trimmed)
            }
        } else if !trimmed.isEmpty {
            try createLinkedNote(
                userId: userId,
                sourceType: sourceType,
                sourceId: sourceId,
                content: trimmed,
                noteEntryRepository: noteEntryRepository,
                entityLinkRepository: entityLinkRepository
            )
        }
    }

    // MARK: - Migrate

    /// Migrates a description link from one source to another (e.g., inbox → ledger during promotion).
    static func migrateLink(
        fromSourceType: EntitySourceType,
        fromSourceId: UUID,
        toSourceType: EntitySourceType,
        toSourceId: UUID,
        userId: UUID,
        entityLinkRepository: EntityLinkRepository
    ) throws {
        if let noteId = try entityLinkRepository.fetchTargetId(
            sourceType: fromSourceType,
            sourceId: fromSourceId,
            targetType: .note,
            context: .expenseNote
        ) {
            let newLink = EntityLink(
                sourceType: toSourceType,
                sourceId: toSourceId,
                targetType: .note,
                targetId: noteId,
                linkContext: .expenseNote,
                userId: userId
            )
            try entityLinkRepository.create(newLink)
            try entityLinkRepository.softDelete(sourceType: fromSourceType, sourceId: fromSourceId)
        }
    }
}
