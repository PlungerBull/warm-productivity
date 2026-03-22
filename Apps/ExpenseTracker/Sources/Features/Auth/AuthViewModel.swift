import Foundation
import SharedModels
import SharedUtilities
import SupabaseClient
import AuthenticationServices

enum AuthState {
    case loading
    case signedOut
    case needsSetup(userId: UUID)
    case signedIn(userId: UUID)
}

@MainActor
@Observable
final class AuthViewModel {
    private let userRepository: UserRepository
    private let bankAccountRepository: BankAccountRepository

    var authState: AuthState = .loading
    var errorMessage: String?

    init(userRepository: UserRepository, bankAccountRepository: BankAccountRepository) {
        self.userRepository = userRepository
        self.bankAccountRepository = bankAccountRepository
    }

    /// Check for an existing Supabase session on app launch.
    func checkSession() async {
        authState = .loading
        guard let session = await SupabaseManager.shared.currentSession else {
            authState = .signedOut
            return
        }
        let userId = session.user.id
        do {
            try userRepository.upsertFromAuth(
                id: userId,
                email: session.user.email,
                displayName: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        routeAfterAuth(userId: userId)
    }

    /// Handle the ASAuthorizationAppleIDCredential from Sign in with Apple.
    /// Follows the exact sequence from system-architecture.md:
    /// 1. Extract identity token
    /// 2. Save fullName to UserDefaults (Apple only provides it on first sign-in)
    /// 3. Sign in with Supabase
    /// 4. Upsert display name to public.users
    /// 5. Upsert local User record
    /// 6. Clear UserDefaults
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        authState = .loading
        do {
            // 1. Extract identity token
            guard let identityTokenData = credential.identityToken,
                  let idToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Failed to get identity token from Apple."
                authState = .signedOut
                return
            }

            // 2. Save full name to App Group UserDefaults immediately
            if let fullName = credential.fullName {
                let displayName = PersonNameComponentsFormatter.localizedString(
                    from: fullName, style: .default
                )
                if !displayName.isEmpty {
                    let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
                    defaults?.set(displayName, forKey: "pendingAppleDisplayName")
                }
            }

            // 3. Retrieve the raw nonce generated before the Apple request
            guard let nonce = AppleSignInNonce.current else {
                errorMessage = "Missing nonce for Apple sign-in."
                authState = .signedOut
                return
            }

            // 4. Sign in with Supabase
            let session = try await SupabaseManager.shared.signInWithApple(
                idToken: idToken, nonce: nonce
            )
            let userId = session.user.id

            // 5. Upsert display name to Supabase if we saved one
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
            if let pendingName = defaults?.string(forKey: "pendingAppleDisplayName") {
                try? await SupabaseManager.shared.upsertDisplayName(
                    userId: userId, displayName: pendingName
                )
                defaults?.removeObject(forKey: "pendingAppleDisplayName")

                // 6. Upsert local user with name
                try userRepository.upsertFromAuth(
                    id: userId, email: session.user.email, displayName: pendingName
                )
            } else {
                try userRepository.upsertFromAuth(
                    id: userId, email: session.user.email, displayName: nil
                )
            }

            // 7. Route based on setup status
            routeAfterAuth(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            authState = .signedOut
        }
    }

    func signOut() async {
        do {
            try await SupabaseManager.shared.signOut()
            authState = .signedOut
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    #if targetEnvironment(simulator)
    /// Debug-only: bypass Apple auth and create a local test user.
    func signInAsTestUser() {
        guard let testUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") else {
            assertionFailure("Invalid test UUID literal")
            return
        }
        do {
            try userRepository.upsertFromAuth(
                id: testUserId,
                email: "test@warmproductivity.local",
                displayName: "Test User"
            )
            routeAfterAuth(userId: testUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    /// Determine whether the user has completed onboarding.
    /// Setup is "complete" if at least one bank account exists locally.
    private func routeAfterAuth(userId: UUID) {
        do {
            let hasAccounts = try bankAccountRepository.hasAnyAccounts(userId: userId)
            authState = hasAccounts ? .signedIn(userId: userId) : .needsSetup(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            authState = .needsSetup(userId: userId)
        }
    }
}
