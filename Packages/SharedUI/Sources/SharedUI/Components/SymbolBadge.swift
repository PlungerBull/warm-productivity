import SwiftUI

// MARK: - Symbol Badge

/// Renders a token symbol ($, @, #) in a tinted rounded square.
/// Used in the sidebar for bank accounts, categories, and hashtags.
public struct SymbolBadge: View {
    let symbol: String
    let color: Color

    public init(symbol: String, color: Color) {
        self.symbol = symbol
        self.color = color
    }

    public var body: some View {
        Text(symbol)
            .font(.system(size: WPSymbolBadgeStyle.fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .frame(
                width: WPSymbolBadgeStyle.size,
                height: WPSymbolBadgeStyle.size
            )
            .background(color.opacity(WPSymbolBadgeStyle.backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: WPSymbolBadgeStyle.cornerRadius))
    }
}
