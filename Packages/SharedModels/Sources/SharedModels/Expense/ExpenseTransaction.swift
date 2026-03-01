import Foundation
import SwiftData

@Model
public final class ExpenseTransaction {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var title: String
    public var amountCents: Int64
    public var amountHomeCents: Int64?
    public var date: Date
    public var accountId: UUID
    public var categoryId: UUID
    public var exchangeRate: Decimal
    public var transferId: UUID?
    public var inboxId: UUID?
    public var reconciliationId: UUID?
    public var cleared: Bool
    public var sourceText: String?
    public var receiptPhotoUrl: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        amountCents: Int64,
        amountHomeCents: Int64? = nil,
        date: Date,
        accountId: UUID,
        categoryId: UUID,
        exchangeRate: Decimal = 1.0,
        transferId: UUID? = nil,
        inboxId: UUID? = nil,
        reconciliationId: UUID? = nil,
        cleared: Bool = false,
        sourceText: String? = nil,
        receiptPhotoUrl: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.amountCents = amountCents
        self.amountHomeCents = amountHomeCents
        self.date = date
        self.accountId = accountId
        self.categoryId = categoryId
        self.exchangeRate = exchangeRate
        self.transferId = transferId
        self.inboxId = inboxId
        self.reconciliationId = reconciliationId
        self.cleared = cleared
        self.sourceText = sourceText
        self.receiptPhotoUrl = receiptPhotoUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
