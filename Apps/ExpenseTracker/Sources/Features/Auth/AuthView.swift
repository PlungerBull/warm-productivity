import SwiftUI
import SharedUI
import AuthenticationServices

struct AuthView: View {
    @State private var viewModel: AuthViewModel

    init(viewModel: AuthViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Line-art app icon
            ZStack {
                RoundedRectangle(cornerRadius: WPCornerRadius.large)
                    .stroke(Color.wpPrimary, lineWidth: 2.5)
                    .frame(width: 72, height: 72)

                Image(systemName: "doc.text")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.wpPrimary)
            }
            .padding(.bottom, WPSpacing.lg)

            // Title and subtitle
            Text("Warm Productivity")
                .font(.wpTitle)
                .foregroundStyle(Color.wpTextPrimary)
                .padding(.bottom, 6)

            Text("Expense Tracker")
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextSecondary)

            Spacer()

            // Error banner
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.clearError()
                }
                .padding(.horizontal, WPSpacing.lg)
                .padding(.bottom, WPSpacing.md)
            }

            // Sign in with Apple button
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
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
            .padding(.horizontal, WPSpacing.lg)

            #if targetEnvironment(simulator)
            Button {
                viewModel.signInAsTestUser()
            } label: {
                Text("Sign in as Test User")
                    .font(.wpCallout)
                    .foregroundStyle(Color.wpPrimary)
            }
            .padding(.top, WPSpacing.sm)
            #endif

            // Privacy text
            Text("Your data stays private. We use Apple's authentication \u{2014} no passwords stored.")
                .font(.wpCaption)
                .foregroundStyle(Color.wpTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, WPSpacing.xl)
                .padding(.top, 20)
                .padding(.bottom, WPSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .accessibilityElement(children: .contain)
    }
}
