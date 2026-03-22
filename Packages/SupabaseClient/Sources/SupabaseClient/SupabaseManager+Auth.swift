import Foundation
import Supabase

extension SupabaseManager {

    /// Returns the current Supabase session if one exists in the Keychain, nil otherwise.
    public var currentSession: Session? {
        get async {
            try? await client.auth.session
        }
    }

    /// Signs in with Apple using the identity token from `ASAuthorizationAppleIDCredential`.
    public func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    /// Signs out the current user, clearing the Keychain-stored session.
    public func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Upserts the user's display name to the `public.users` table.
    /// Called after Apple sign-in to persist the name Apple provided on first sign-in.
    public func upsertDisplayName(userId: UUID, displayName: String) async throws {
        try await client.from("users")
            .upsert(
                [
                    "id": userId.uuidString,
                    "display_name": displayName,
                    "updated_at": ISO8601DateFormatter().string(from: Date()),
                ],
                onConflict: "id"
            )
            .execute()
    }
}
