import Foundation

/// Protocol for SwiftData models that support delta sync via version tracking.
/// All mutable models have updatedAt, version, and deletedAt fields.
public protocol VersionedModel: AnyObject {
    var updatedAt: Date { get set }
    var version: Int { get set }
    var deletedAt: Date? { get set }
}

extension VersionedModel {
    /// Bumps version and sets updatedAt to now. Call before saving any update.
    public func markUpdated() {
        updatedAt = Date()
        version += 1
    }

    /// Sets deletedAt, bumps version and updatedAt. Soft-delete pattern.
    public func markDeleted() {
        deletedAt = Date()
        updatedAt = Date()
        version += 1
    }
}

// MARK: - Retroactive Conformances

extension ExpenseTransaction: VersionedModel {}
extension ExpenseTransactionInbox: VersionedModel {}
extension ExpenseCategory: VersionedModel {}
extension ExpenseBankAccount: VersionedModel {}
extension ExpenseHashtag: VersionedModel {}
extension ExpenseReconciliation: VersionedModel {}
extension ExpenseBudget: VersionedModel {}
extension ExpenseTransactionHashtag: VersionedModel {}
extension TransactionShare: VersionedModel {}
extension UserSettings: VersionedModel {}
extension UserSubscription: VersionedModel {}
extension EntityLink: VersionedModel {}
extension NoteNotebook: VersionedModel {}
extension NoteEntry: VersionedModel {}
extension NoteHashtag: VersionedModel {}
extension NoteEntryHashtag: VersionedModel {}
extension TodoCategory: VersionedModel {}
extension TodoTask: VersionedModel {}
extension TodoRecurrenceRule: VersionedModel {}
extension TodoHashtag: VersionedModel {}
extension TodoTaskHashtag: VersionedModel {}
extension TodoCategoryMember: VersionedModel {}
extension StreakCompletion: VersionedModel {}
