import Foundation
import SwiftData

@Model
public final class UserSubscription {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var userId: UUID
    public var productId: String?
    public var planTier: PlanTier
    public var status: SubscriptionStatus
    public var autoRenewEnabled: Bool
    public var trialStartDate: Date?
    public var trialEndDate: Date?
    public var currentPeriodStart: Date?
    public var currentPeriodEnd: Date?
    public var gracePeriodEnd: Date?
    public var cancellationDate: Date?
    public var originalTransactionId: String?
    public var environment: SubscriptionEnvironment
    public var platform: String
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var deletedAt: Date?
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        productId: String? = nil,
        planTier: PlanTier = .free,
        status: SubscriptionStatus = .trialing,
        autoRenewEnabled: Bool = true,
        trialStartDate: Date? = nil,
        trialEndDate: Date? = nil,
        currentPeriodStart: Date? = nil,
        currentPeriodEnd: Date? = nil,
        gracePeriodEnd: Date? = nil,
        cancellationDate: Date? = nil,
        originalTransactionId: String? = nil,
        environment: SubscriptionEnvironment = .production,
        platform: String = "ios",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        deletedAt: Date? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.productId = productId
        self.planTier = planTier
        self.status = status
        self.autoRenewEnabled = autoRenewEnabled
        self.trialStartDate = trialStartDate
        self.trialEndDate = trialEndDate
        self.currentPeriodStart = currentPeriodStart
        self.currentPeriodEnd = currentPeriodEnd
        self.gracePeriodEnd = gracePeriodEnd
        self.cancellationDate = cancellationDate
        self.originalTransactionId = originalTransactionId
        self.environment = environment
        self.platform = platform
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }
}
