import Supabase
import Foundation
import SharedUtilities

/// Singleton entry point for all Supabase SDK access.
/// Reads credentials from Info.plist (injected via xcconfig files).
/// Configures shared Keychain access group for cross-app auth.
public final class SupabaseManager: Sendable {
    public static let shared = SupabaseManager()

    public let client: SupabaseClient

    private init() {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String
        else {
            fatalError("Missing Supabase configuration in Info.plist. Ensure SUPABASE_URL and SUPABASE_ANON_KEY are set via xcconfig.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: KeychainLocalStorage(
                        accessGroup: AppConstants.appGroupIdentifier
                    )
                )
            )
        )
    }
}
