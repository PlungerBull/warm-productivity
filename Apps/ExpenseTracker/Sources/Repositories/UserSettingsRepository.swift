import Foundation
import SwiftData
import SharedModels

@MainActor
final class UserSettingsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSettings(userId: UUID) throws -> UserSettings? {
        let descriptor = FetchDescriptor<UserSettings>(
            predicate: #Predicate { $0.userId == userId && $0.deletedAt == nil }
        )
        return try modelContext.fetch(descriptor).first
    }

    func createSettings(userId: UUID, mainCurrency: String) throws {
        let settings = UserSettings(
            userId: userId,
            mainCurrency: mainCurrency,
            displayTimezone: TimeZone.current.identifier
        )
        modelContext.insert(settings)
        try modelContext.save()
    }

    func updateMainCurrency(userId: UUID, currency: String) throws {
        guard let settings = try fetchSettings(userId: userId) else { return }
        settings.mainCurrency = currency
        settings.markUpdated()
        try modelContext.save()
    }

    func updateTheme(userId: UUID, theme: String) throws {
        guard let settings = try fetchSettings(userId: userId) else { return }
        settings.theme = theme
        settings.markUpdated()
        try modelContext.save()
    }

    func updateTimezone(userId: UUID, timezone: String) throws {
        guard let settings = try fetchSettings(userId: userId) else { return }
        settings.displayTimezone = timezone
        settings.markUpdated()
        try modelContext.save()
    }

    func updateSettings(userId: UUID, update: (UserSettings) -> Void) throws {
        guard let settings = try fetchSettings(userId: userId) else { return }
        update(settings)
        settings.markUpdated()
        try modelContext.save()
    }
}
