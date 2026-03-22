import Foundation
import SwiftData
import SharedModels

@MainActor
final class ExchangeRateRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Fetch the exchange rate for a specific currency pair on a specific date.
    func fetchRate(base: String, target: String, date: Date) throws -> ExchangeRate? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate {
                $0.baseCurrency == base
                    && $0.targetCurrency == target
                    && $0.rateDate >= dayStart
                    && $0.rateDate < dayEnd
            },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch the most recent exchange rate for a currency pair regardless of date.
    func fetchLatestRate(base: String, target: String) throws -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate {
                $0.baseCurrency == base && $0.targetCurrency == target
            },
            sortBy: [SortDescriptor(\.rateDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }
}
