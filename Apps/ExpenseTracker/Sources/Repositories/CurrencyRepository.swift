import Foundation
import SwiftData
import SharedModels

@MainActor
final class CurrencyRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Fetch all currencies from local SwiftData, sorted by code.
    func fetchAll() throws -> [GlobalCurrency] {
        let descriptor = FetchDescriptor<GlobalCurrency>(
            sortBy: [SortDescriptor(\.code)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByCode(_ code: String) throws -> GlobalCurrency? {
        let descriptor = FetchDescriptor<GlobalCurrency>(
            predicate: #Predicate { $0.code == code }
        )
        return try modelContext.fetch(descriptor).first
    }

    func insert(_ currency: GlobalCurrency) throws {
        // Skip if already exists (unique constraint on code)
        if try fetchByCode(currency.code) != nil { return }
        modelContext.insert(currency)
        try modelContext.save()
    }
}
