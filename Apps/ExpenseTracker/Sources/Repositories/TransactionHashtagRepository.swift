import Foundation
import SwiftData
import SharedModels

@MainActor
final class TransactionHashtagRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchForTransaction(transactionId: UUID, source: TransactionSourceType) throws -> [ExpenseTransactionHashtag] {
        // SwiftData #Predicate doesn't support custom enum types as captured values.
        // Query by transactionId only, filter enum in memory.
        let descriptor = FetchDescriptor<ExpenseTransactionHashtag>(
            predicate: #Predicate {
                $0.transactionId == transactionId && $0.deletedAt == nil
            }
        )
        return try modelContext.fetch(descriptor).filter { $0.transactionSource == source }
    }

    func fetchTransactionIds(hashtagId: UUID) throws -> [UUID] {
        let descriptor = FetchDescriptor<ExpenseTransactionHashtag>(
            predicate: #Predicate {
                $0.hashtagId == hashtagId && $0.deletedAt == nil
            }
        )
        return try modelContext.fetch(descriptor).map(\.transactionId)
    }

    func link(transactionId: UUID, source: TransactionSourceType, hashtagId: UUID, userId: UUID) throws {
        // Check if link already exists
        let existing = try fetchForTransaction(transactionId: transactionId, source: source)
        if existing.contains(where: { $0.hashtagId == hashtagId }) { return }

        let link = ExpenseTransactionHashtag(
            transactionId: transactionId,
            transactionSource: source,
            hashtagId: hashtagId,
            userId: userId
        )
        modelContext.insert(link)
        try modelContext.save()
    }

    func unlink(transactionId: UUID, source: TransactionSourceType, hashtagId: UUID) throws {
        let links = try fetchForTransaction(transactionId: transactionId, source: source)
        for link in links where link.hashtagId == hashtagId {
            link.markDeleted()
        }
        try modelContext.save()
    }

    func unlinkAll(transactionId: UUID, source: TransactionSourceType) throws {
        let links = try fetchForTransaction(transactionId: transactionId, source: source)
        for link in links {
            link.markDeleted()
        }
        if !links.isEmpty {
            try modelContext.save()
        }
    }
}
