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
        VStack(spacing: WPSpacing.md) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.wpTextTertiary)
            }

            VStack(spacing: WPSpacing.xs) {
                Text(title)
                    .font(.wpHeadline)
                    .foregroundStyle(Color.wpTextPrimary)

                if let message {
                    Text(message)
                        .font(.wpCallout)
                        .foregroundStyle(Color.wpTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.wpSubheadline)
                        .foregroundStyle(Color.wpPrimary)
                }
                .padding(.top, WPSpacing.xs)
            }
        }
        .padding(.horizontal, WPSpacing.xl)
        .padding(.vertical, WPSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
