import SwiftUI

/// Standard loading indicator with optional message.
///
/// Usage:
/// ```swift
/// LoadingView()
/// LoadingView(message: "Loading transactions...")
/// ```
public struct LoadingView: View {
    private let message: String?
    @State private var appeared = false

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: WPSpacing.sm) {
            ProgressView()
                .controlSize(.regular)
                .tint(Color.wpTextTertiary)

            if let message {
                Text(message)
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
            }
        }
        .opacity(appeared ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}
