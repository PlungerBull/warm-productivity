import Foundation
import SwiftData
import SharedModels
import SupabaseClient

/// Syncs currencies from Supabase into local SwiftData.
/// Separated from CurrencyRepository so the repository stays pure (no SupabaseClient import).
@MainActor
final class CurrencySyncService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Row shape returned by `select()` on `global_currencies`.
    private struct CurrencyRow: Decodable {
        let code: String
        let name: String
        let symbol: String
        let flag: String?
        let decimal_places: Int
    }

    /// Fetch all currencies from Supabase and upsert into local SwiftData.
    func syncFromRemote() async throws {
        let rows: [CurrencyRow] = try await SupabaseManager.shared.client
            .from("global_currencies")
            .select()
            .execute()
            .value

        for row in rows {
            let existing = try fetchByCode(row.code)
            if let existing {
                existing.name = row.name
                existing.symbol = row.symbol
                existing.flag = row.flag
                existing.decimalPlaces = row.decimal_places
            } else {
                let currency = GlobalCurrency(
                    code: row.code,
                    name: row.name,
                    symbol: row.symbol,
                    flag: row.flag,
                    decimalPlaces: row.decimal_places
                )
                modelContext.insert(currency)
            }
        }
        try modelContext.save()
    }

    private func fetchByCode(_ code: String) throws -> GlobalCurrency? {
        let descriptor = FetchDescriptor<GlobalCurrency>(
            predicate: #Predicate { $0.code == code }
        )
        return try modelContext.fetch(descriptor).first
    }
}
