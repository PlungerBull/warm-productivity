import SwiftUI

/// Key type for the custom calculator-style numpad.
public enum NumpadKey: Sendable {
    case digit(Int)
    case decimal
    case backspace
}

/// Reusable 4x3 calculator-style numpad grid.
/// Reports key presses via a closure — the parent manages the amount string.
public struct NumpadView: View {
    private let onKeyPress: (NumpadKey) -> Void

    public init(onKeyPress: @escaping (NumpadKey) -> Void) {
        self.onKeyPress = onKeyPress
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: WPNumpadStyle.gridSpacing), count: 3)

    public var body: some View {
        LazyVGrid(columns: columns, spacing: WPNumpadStyle.gridSpacing) {
            ForEach(1...9, id: \.self) { digit in
                numpadKey(label: "\(digit)") { onKeyPress(.digit(digit)) }
            }
            numpadKey(label: ".") { onKeyPress(.decimal) }
            numpadKey(label: "0") { onKeyPress(.digit(0)) }
            backspaceKey()
        }
    }

    private func numpadKey(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: WPNumpadStyle.keyFontSize, weight: .medium))
                .foregroundStyle(Color.wpTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: WPNumpadStyle.keyHeight)
                .background(Color.wpSurface)
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(NumpadButtonStyle())
    }

    private func backspaceKey() -> some View {
        Button { onKeyPress(.backspace) } label: {
            Image(systemName: "delete.left")
                .font(.system(size: WPNumpadStyle.backspaceIconSize, weight: .medium))
                .foregroundStyle(Color.wpTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: WPNumpadStyle.keyHeight)
                .background(Color.wpSurface)
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(NumpadButtonStyle())
    }
}

/// Press animation for numpad keys — scale down slightly on tap.
private struct NumpadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.snappy(duration: 0.1), value: configuration.isPressed)
    }
}
