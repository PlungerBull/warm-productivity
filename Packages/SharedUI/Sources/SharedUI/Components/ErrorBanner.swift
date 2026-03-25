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

    public init(message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }

    /// Adaptive error text: dark maroon in light mode, soft pink in dark mode.
    private var errorTextColor: Color {
        Color(light: Color(hex: "7f1d1d"), dark: Color(hex: "fecaca"))
    }

    /// Subtle error background tint.
    private var errorBackground: Color {
        Color(light: Color(hex: "fef2f2"), dark: Color.wpError.opacity(0.08))
    }

    /// Matching border color.
    private var errorBorderColor: Color {
        Color(light: Color(hex: "fecaca").opacity(0.8), dark: Color.wpError.opacity(0.15))
    }

    public var body: some View {
        HStack(spacing: WPSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.wpError)

            Text(message)
                .font(.wpCaption)
                .foregroundStyle(errorTextColor)
                .lineLimit(2)

            Spacer(minLength: WPSpacing.xxs)

            if let onDismiss {
                Button {
                    dismiss(onDismiss)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.wpTextTertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(.horizontal, WPSpacing.sm)
        .padding(.vertical, WPSpacing.xs)
        .background(errorBackground)
        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: WPCornerRadius.small)
                .stroke(errorBorderColor, lineWidth: 0.5)
        )
        .padding(.horizontal, WPSpacing.md)
        .offset(y: isVisible ? 0 : -12)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }

    private func dismiss(_ handler: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            handler()
        }
    }
}
