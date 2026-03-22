import Foundation
import SwiftData
import SharedModels

@MainActor
final class UserRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchUser(id: UUID) throws -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func upsertFromAuth(id: UUID, email: String?, displayName: String?) throws {
        if let existing = try fetchUser(id: id) {
            if let email { existing.email = email }
            if let displayName { existing.displayName = displayName }
            existing.updatedAt = Date()
        } else {
            let user = User(id: id, email: email, displayName: displayName)
            modelContext.insert(user)
        }
        try modelContext.save()
    }
}
