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

    public var body: some View {
        HStack(spacing: WPSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.wpCallout)
                .foregroundStyle(Color.wpError)

            Text(message)
                .font(.wpCaption)
                .foregroundStyle(Color.wpTextPrimary)
                .lineLimit(2)

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
                        .font(.wpCaption2.weight(.medium))
                        .foregroundStyle(Color.wpTextSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(.horizontal, WPSpacing.sm)
        .padding(.vertical, WPSpacing.xs)
        .background(Color.wpError.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: WPCornerRadius.small)
                .stroke(Color.wpError.opacity(0.2), lineWidth: 1)
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
