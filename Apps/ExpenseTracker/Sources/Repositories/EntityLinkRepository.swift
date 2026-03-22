import Foundation
import SwiftData
import SharedModels

@MainActor
final class EntityLinkRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchLinks(sourceType: EntitySourceType, sourceId: UUID) throws -> [EntityLink] {
        // SwiftData #Predicate doesn't support custom enum types as captured values.
        // Query by sourceId (UUID) only, then filter enum in memory.
        let descriptor = FetchDescriptor<EntityLink>(
            predicate: #Predicate {
                $0.sourceId == sourceId && $0.deletedAt == nil
            }
        )
        return try modelContext.fetch(descriptor).filter { $0.sourceType == sourceType }
    }

    func fetchTargetId(
        sourceType: EntitySourceType,
        sourceId: UUID,
        targetType: EntitySourceType,
        context: EntityLinkContext
    ) throws -> UUID? {
        let links = try fetchLinks(sourceType: sourceType, sourceId: sourceId)
        return links.first { $0.targetType == targetType && $0.linkContext == context }?.targetId
    }

    func create(_ link: EntityLink) throws {
        modelContext.insert(link)
        try modelContext.save()
    }

    func softDelete(sourceType: EntitySourceType, sourceId: UUID) throws {
        let links = try fetchLinks(sourceType: sourceType, sourceId: sourceId)
        for link in links {
            link.markDeleted()
        }
        if !links.isEmpty {
            try modelContext.save()
        }
    }
}
