import SwiftUI

// MARK: - Left Border Modifier

/// Adds a colored vertical border strip on the leading edge of a view.
/// Used for category color on ledger rows and readiness indicator on inbox rows.
public struct LeftBorderModifier: ViewModifier {
    let color: Color
    let width: CGFloat

    public init(color: Color, width: CGFloat = 3) {
        self.color = color
        self.width = width
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(color)
                    .frame(width: width)
            }
    }
}

public extension View {
    /// Applies a colored left border strip. Pass `nil` for no border.
    func wpLeftBorder(_ color: Color?, width: CGFloat = 3) -> some View {
        modifier(LeftBorderModifier(color: color ?? .clear, width: color == nil ? 0 : width))
    }
}

// MARK: - List Row Style

/// Standard list row styling: padding, bottom separator, min height.
public struct WPListRowModifier: ViewModifier {
    let verticalPadding: CGFloat
    let horizontalPadding: CGFloat
    let showSeparator: Bool

    public init(
        verticalPadding: CGFloat = 10,
        horizontalPadding: CGFloat = WPSpacing.md,
        showSeparator: Bool = true
    ) {
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self.showSeparator = showSeparator
    }

    public func body(content: Content) -> some View {
        content
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(Color.wpGlassBackground)
            .overlay(alignment: .bottom) {
                if showSeparator {
                    Rectangle()
                        .fill(Color.wpBorder)
                        .frame(height: 0.5)
                }
            }
    }
}

public extension View {
    func wpListRow(showSeparator: Bool = true) -> some View {
        modifier(WPListRowModifier(showSeparator: showSeparator))
    }
}

// MARK: - Symbol Badge Style

/// Renders a symbol character ($, @, #) in a tinted rounded square.
/// Used in the sidebar for bank accounts, categories, and hashtags.
public struct WPSymbolBadgeStyle {
    public static let size: CGFloat = 28
    public static let cornerRadius: CGFloat = 6
    public static let fontSize: CGFloat = 14
    public static let backgroundOpacity: Double = 0.12
}

// MARK: - Toolbar Pill Style

/// Pill button used in the quick entry toolbar.
public enum WPToolbarPillState {
    case selected
    case unselected
    case missing
}

public struct WPToolbarPillModifier: ViewModifier {
    let state: WPToolbarPillState
    let color: Color

    public init(state: WPToolbarPillState, color: Color = Color.wpTextSecondary) {
        self.state = state
        self.color = color
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        let base = content
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(foregroundColor)

        if state == .missing {
            base
                .background(Color.wpWarning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.wpWarning.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
        } else {
            base
                .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .selected: color
        case .unselected: Color.wpTextTertiary
        case .missing: Color.wpWarning
        }
    }
}

public extension View {
    func wpToolbarPill(state: WPToolbarPillState, color: Color = Color.wpTextSecondary) -> some View {
        modifier(WPToolbarPillModifier(state: state, color: color))
    }
}

// MARK: - Circular Send Button Style

/// The circular send/submit button used in quick entry.
public struct WPSendButtonStyle {
    public static let size: CGFloat = 34
    public static let iconSize: CGFloat = 16
}

// MARK: - Content Sheet Style

/// Constants for the half-screen content-first bottom sheet (transaction detail).
public struct WPContentSheetStyle {
    public static let handleWidth: CGFloat = 36
    public static let handleHeight: CGFloat = 4
    public static let handleCornerRadius: CGFloat = 2
    public static let titleFontSize: CGFloat = 22
    public static let amountFontSize: CGFloat = 28
}

// MARK: - Tag Chip Style

/// Small colored chip for displaying @category and #hashtag tags.
public struct WPTagChipModifier: ViewModifier {
    let color: Color

    public init(color: Color) {
        self.color = color
    }

    public func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

public extension View {
    func wpTagChip(color: Color) -> some View {
        modifier(WPTagChipModifier(color: color))
    }
}

// MARK: - Inbox Badge Style

/// Small count badge pill (e.g., inbox count).
public struct WPBadgeStyle {
    public static let minWidth: CGFloat = 20
    public static let height: CGFloat = 20
    public static let cornerRadius: CGFloat = 10
    public static let horizontalPadding: CGFloat = 6
}
