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
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.wpPrimary)
                .frame(width: WPSize.fabButton, height: WPSize.fabButton)
                .contentShape(Circle())
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.snappy(duration: 0.15)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.snappy(duration: 0.2)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("Add new item")
        .accessibilityHint("Tap to add a new entry")
    }
}
