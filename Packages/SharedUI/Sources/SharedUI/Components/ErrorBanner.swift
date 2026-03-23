import SwiftUI

/// Non-intrusive error banner that slides in from the top of a view.
///
/// Place at the top of your content using an overlay or VStack. The banner
/// supports manual dismiss and optional auto-dismiss after a timeout.
///
/// Usage:
/// ```swift
/// VStack {
///     if let error = viewModel.errorMessage {
///         ErrorBanner(message: error) {
///             viewModel.errorMessage = nil
///         }
///     }
///     // ... content
/// }
/// ```
public struct ErrorBanner: View {
    private let message: String
    private let onDismiss: (() -> Void)?
    @State private var isVisible = false

    @Environment(\.colorScheme) private var colorScheme

    public init(message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }

    /// Light: dark red #991b1b. Dark: soft pink #fca5a5.
    private var errorTextColor: Color {
        colorScheme == .dark
            ? Color(hex: "fca5a5")
            : Color(hex: "991b1b")
    }

    /// Light: #fef2f2. Dark: error at 10% opacity.
    private var errorBackground: Color {
        colorScheme == .dark
            ? Color.wpError.opacity(0.1)
            : Color(hex: "fef2f2")
    }

    /// Light: #fecaca. Dark: error at 20% opacity.
    private var errorBorderColor: Color {
        colorScheme == .dark
            ? Color.wpError.opacity(0.2)
            : Color(hex: "fecaca")
    }

    public var body: some View {
        HStack(spacing: WPSpacing.xs) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16))
                .foregroundStyle(Color.wpError)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(errorTextColor)
                .lineLimit(2)
                .lineSpacing(2)

            Spacer(minLength: WPSpacing.xs)

            if let onDismiss {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.wpTextTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(.horizontal, WPSpacing.md)
        .padding(.vertical, WPSpacing.sm)
        .background(errorBackground)
        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: WPCornerRadius.small)
                .stroke(errorBorderColor, lineWidth: 1)
        )
        .padding(.horizontal, WPSpacing.md)
        .offset(y: isVisible ? 0 : -20)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}
