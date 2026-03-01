import Foundation
import SwiftData

@Model
public final class ExchangeRate {
    @Attribute(.unique) public var id: UUID
    public var baseCurrency: String
    public var targetCurrency: String
    public var rate: Decimal
    public var rateDate: Date
    public var fetchedAt: Date
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        baseCurrency: String,
        targetCurrency: String,
        rate: Decimal,
        rateDate: Date,
        fetchedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.baseCurrency = baseCurrency
        self.targetCurrency = targetCurrency
        self.rate = rate
        self.rateDate = rateDate
        self.fetchedAt = fetchedAt
        self.createdAt = createdAt
    }
}
