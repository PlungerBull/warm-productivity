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

            // Line-art brand mark — rounded square with stylized "E" letterform
            BrandMark()
                .stroke(Color.wpPrimary, lineWidth: 2.5)
                .frame(width: 72, height: 72)
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
            Text("Your data stays private. We use Apple's\nauthentication \u{2014} no passwords stored.")
                .font(.wpCaption)
                .foregroundStyle(Color.wpTextTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 20)
                .padding(.bottom, WPSpacing.xl)
        }
        .padding(.horizontal, WPSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wpBackground.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Brand Mark

/// Custom line-art brand mark: rounded square outline with a stylized "E" letterform.
/// Matches the SVG in ui-polish-mockups.html.
private struct BrandMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Outer rounded rectangle (inset to account for stroke)
        let inset: CGFloat = rect.width * 4 / 72 // proportional to 72pt design
        let cornerRadius: CGFloat = rect.width * 16 / 72
        path.addRoundedRect(
            in: rect.insetBy(dx: inset, dy: inset),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        // Stylized "E" letterform inside
        // Scale coordinates from the 72pt design space
        let scale = rect.width / 72

        // Left vertical stroke: (22, 24) → (22, 48)
        path.move(to: CGPoint(x: 22 * scale, y: 48 * scale))
        path.addLine(to: CGPoint(x: 22 * scale, y: 24 * scale))

        // Top horizontal: (22, 24) → (42, 24)
        path.addLine(to: CGPoint(x: 42 * scale, y: 24 * scale))

        // Middle horizontal: (22, 36) → (38, 36)
        path.move(to: CGPoint(x: 22 * scale, y: 36 * scale))
        path.addLine(to: CGPoint(x: 38 * scale, y: 36 * scale))

        // Right vertical stroke: (42, 24) → (42, 48)
        path.move(to: CGPoint(x: 42 * scale, y: 24 * scale))
        path.addLine(to: CGPoint(x: 42 * scale, y: 48 * scale))

        return path
    }
}
