import Foundation
import SharedModels
import SupabaseClient

/// Delta sync engine — placeholder.
/// Full implementation follows the sync-engine skill.
/// Handles: version-based conflict resolution, two-phase push (PRUNE then PLANT),
/// background queue management, and offline-first writes.
public final class SyncEngine: Sendable {
    public static let shared = SyncEngine()
    private init() {}
}
