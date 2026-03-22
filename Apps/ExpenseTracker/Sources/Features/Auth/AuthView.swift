import SwiftUI
import SharedUI
import AuthenticationServices

struct AuthView: View {
    @State private var viewModel: AuthViewModel

    init(viewModel: AuthViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: WPSpacing.xl) {
            Spacer()

            Image(systemName: "dollarsign.circle.fill")
                .font(.wpIconLarge)
                .foregroundStyle(Color.wpPrimary)

            VStack(spacing: WPSpacing.xs) {
                Text("Expense Tracker")
                    .font(.wpLargeTitle)
                    .foregroundStyle(Color.wpTextPrimary)

                Text("Track spending across currencies and accounts")
                    .font(.wpCallout)
                    .foregroundStyle(Color.wpTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.clearError()
                }
            }

            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInNonce.generate()
                request.requestedScopes = [.fullName, .email]
                request.nonce = nonce.hashed
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential
                            as? ASAuthorizationAppleIDCredential else { return }
                    Task {
                        await viewModel.signInWithApple(credential: credential)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
            .padding(.horizontal, WPSpacing.xl)

            #if targetEnvironment(simulator)
            Button {
                viewModel.signInAsTestUser()
            } label: {
                Text("Sign in as Test User")
                    .font(.wpCallout)
                    .foregroundStyle(Color.wpPrimary)
            }
            .padding(.bottom, WPSpacing.lg)
            #endif

            Spacer().frame(height: WPSpacing.md)
        }
        .background(Color.wpBackground)
        .accessibilityElement(children: .contain)
    }
}
