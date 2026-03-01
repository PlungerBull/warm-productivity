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

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: WPSpacing.md) {
            ProgressView()
                .controlSize(.regular)
                .tint(Color.wpPrimary)

            if let message {
                Text(message)
                    .font(.wpCallout)
                    .foregroundStyle(Color.wpTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}
