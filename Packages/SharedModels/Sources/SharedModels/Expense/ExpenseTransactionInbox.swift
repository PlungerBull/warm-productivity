import Foundation
import SwiftData

@Model
public final class ExpenseTransactionInbox {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var title: String
    public var amountCents: Int64?
    public var date: Date?
    public var accountId: UUID?
    public var categoryId: UUID?
    public var exchangeRate: Decimal
    public var isRecurring: Bool
    public var linkedTaskId: UUID?
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
        title: String = "UNTITLED",
        amountCents: Int64? = nil,
        date: Date? = nil,
        accountId: UUID? = nil,
        categoryId: UUID? = nil,
        exchangeRate: Decimal = 1.0,
        isRecurring: Bool = false,
        linkedTaskId: UUID? = nil,
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
        self.date = date
        self.accountId = accountId
        self.categoryId = categoryId
        self.exchangeRate = exchangeRate
        self.isRecurring = isRecurring
        self.linkedTaskId = linkedTaskId
        self.sourceText = sourceText
        self.receiptPhotoUrl = receiptPhotoUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
