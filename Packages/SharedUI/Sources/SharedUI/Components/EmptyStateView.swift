import SwiftUI

/// Centered message with optional icon and action button for empty lists.
///
/// Usage:
/// ```swift
/// EmptyStateView(
///     icon: "tray",
///     title: "Nothing to see here!",
///     message: "Add a transaction.",
///     actionTitle: "Get Started"
/// ) {
///     showQuickEntry = true
/// }
/// ```
public struct EmptyStateView: View {
    private let icon: String?
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        icon: String? = nil,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: WPSpacing.lg) {
            if let icon {
                Image(systemName: icon)
                    .font(.wpIconDecorative)
                    .foregroundStyle(Color.wpTextTertiary.opacity(0.6))
                    .padding(.bottom, WPSpacing.xxs)
            }

            VStack(spacing: WPSpacing.xs) {
                Text(title)
                    .font(.wpSubheadline)
                    .foregroundStyle(Color.wpTextSecondary)

                if let message {
                    Text(message)
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.wpSubheadline)
                        .foregroundStyle(Color.wpOnPrimary)
                        .padding(.horizontal, WPSpacing.lg)
                        .padding(.vertical, WPSpacing.xs)
                        .background(Color.wpPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, WPSpacing.xxs)
            }
        }
        .padding(.horizontal, WPSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
