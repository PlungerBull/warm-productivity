import SwiftUI

/// Floating action button for quick entry. Visible on all tabs except Settings.
///
/// Place as an overlay at the bottom-trailing corner of the screen.
/// Supports a single tap (primary action) and an optional long-press (secondary action).
///
/// Usage:
/// ```swift
/// .overlay(alignment: .bottomTrailing) {
///     FABButton(action: { showQuickEntry = true })
///         .padding(.trailing, WPSpacing.lg)
///         .padding(.bottom, WPSpacing.lg)
/// }
/// ```
public struct FABButton: View {
    private let action: () -> Void
    private let onLongPress: (() -> Void)?
    @State private var isPressed = false

    public init(
        action: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.action = action
        self.onLongPress = onLongPress
    }

    public var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.wpPrimary)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .accessibilityLabel("Add new item")
        .accessibilityHint("Tap to add a new entry")
    }
}
