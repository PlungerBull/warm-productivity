import Foundation

// MARK: - Expense Enums

public enum ExpenseCategoryType: String, Codable {
    case income = "income"
    case expense = "expense"
}

public enum ReconciliationStatus: String, Codable {
    case draft = "draft"
    case completed = "completed"
}

public enum TransactionSourceType: String, Codable {
    case inbox = "inbox"
    case ledger = "ledger"
}

// MARK: - Cross-App Enums

public enum EntitySourceType: String, Codable {
    case expenseInbox = "expense_inbox"
    case expenseLedger = "expense_ledger"
    case task = "task"
    case note = "note"
}

public enum EntityLinkContext: String, Codable {
    case expenseNote = "expense_note"
    case taskNote = "task_note"
    case taskExpense = "task_expense"
    case noteCreatedExpense = "note_created_expense"
    case noteCreatedTask = "note_created_task"
}

public enum ActionType: String, Codable {
    case created = "created"
    case deleted = "deleted"
    case completed = "completed"
    case modified = "modified"
}

// MARK: - Subscription Enums

public enum PlanTier: String, Codable {
    case free = "free"
    case pro = "pro"
}

public enum SubscriptionStatus: String, Codable {
    case trialing = "trialing"
    case active = "active"
    case gracePeriod = "grace_period"
    case billingRetry = "billing_retry"
    case expired = "expired"
    case cancelled = "cancelled"
    case revoked = "revoked"
}

public enum SubscriptionEnvironment: String, Codable {
    case sandbox = "sandbox"
    case production = "production"
}

// MARK: - Recurrence Enums

public enum RecurrencePattern: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case specificDays = "specific_days"
    case monthly = "monthly"
    case yearly = "yearly"
}

public enum RecurrenceAnchor: String, Codable {
    case fixed = "fixed"
    case afterCompletion = "after_completion"
}

// MARK: - Todo Enums

public enum SubtaskMode: String, Codable {
    case independent = "independent"
    case gated = "gated"
}

public enum StreakFrequency: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

public enum StreakGoalType: String, Codable {
    case achieveAll = "achieve_all"
    case reachAmount = "reach_amount"
}

public enum StreakRecordingMethod: String, Codable {
    case auto = "auto"
    case manual = "manual"
    case completeAll = "complete_all"
}

public enum TodoMemberRole: String, Codable {
    case owner = "owner"
    case member = "member"
}
