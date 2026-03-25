import SwiftUI

/// A suggestion item for the autocomplete dropdown.
public struct AutocompleteSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let secondaryText: String?
    public let color: Color?

    public init(id: UUID = UUID(), text: String, secondaryText: String? = nil, color: Color? = nil) {
        self.id = id
        self.text = text
        self.secondaryText = secondaryText
        self.color = color
    }
}

/// Reusable token-based autocomplete field.
/// The caller provides filtered suggestions; this component handles display and selection.
///
/// Usage:
/// ```swift
/// TokenAutocompleteField(
///     text: $categoryText,
///     placeholder: "Category",
///     suggestions: filteredCategories,
///     onSelect: { suggestion in selectedCategory = suggestion },
///     onCreate: { name in createNewCategory(name) }
/// )
/// ```
public struct TokenAutocompleteField: View {
    @Binding private var text: String
    private let placeholder: String
    private let suggestions: [AutocompleteSuggestion]
    private let onSelect: (AutocompleteSuggestion) -> Void
    private let onCreate: ((String) -> Void)?
    @State private var isFocused: Bool = false
    @FocusState private var fieldFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Type to search...",
        suggestions: [AutocompleteSuggestion] = [],
        onSelect: @escaping (AutocompleteSuggestion) -> Void,
        onCreate: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.suggestions = suggestions
        self.onSelect = onSelect
        self.onCreate = onCreate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: WPSpacing.xxs) {
            TextField(placeholder, text: $text)
                .font(.wpBody)
                .focused($fieldFocused)
                .onChange(of: fieldFocused) { _, newValue in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isFocused = newValue
                    }
                }
                .onSubmit {
                    if let first = suggestions.first {
                        selectSuggestion(first)
                    }
                }

            if isFocused && !text.isEmpty {
                dropdownContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var dropdownContent: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    Button {
                        selectSuggestion(suggestion)
                    } label: {
                        suggestionRow(suggestion)
                    }
                    .buttonStyle(.plain)

                    if index < suggestions.count - 1 {
                        Divider()
                            .padding(.leading, WPSpacing.sm)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: WPCornerRadius.small))
        } else if let onCreate {
            Button {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onCreate(trimmed)
                    text = ""
                    fieldFocused = false
                }
            } label: {
                HStack(spacing: WPSpacing.xs) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.wpPrimary)
                    Text("Create '\(text.trimmingCharacters(in: .whitespacesAndNewlines))'")
                        .font(.wpCallout)
                        .foregroundStyle(Color.wpTextPrimary)
                }
                .padding(.horizontal, WPSpacing.sm)
                .padding(.vertical, WPSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: WPCornerRadius.small))
        }
    }

    private func suggestionRow(_ suggestion: AutocompleteSuggestion) -> some View {
        HStack(spacing: WPSpacing.xs) {
            if let color = suggestion.color {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(suggestion.text)
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextPrimary)
            if let secondary = suggestion.secondaryText {
                Spacer()
                Text(secondary)
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
            }
        }
        .padding(.horizontal, WPSpacing.sm)
        .padding(.vertical, WPSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func selectSuggestion(_ suggestion: AutocompleteSuggestion) {
        text = suggestion.text
        onSelect(suggestion)
        fieldFocused = false
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack(spacing: WPSpacing.lg) {
        TokenAutocompleteField(
            text: $text,
            placeholder: "Search categories...",
            suggestions: [
                AutocompleteSuggestion(text: "Food", secondaryText: "Expense", color: .green),
                AutocompleteSuggestion(text: "Transport", secondaryText: "Expense", color: .blue),
            ],
            onSelect: { _ in },
            onCreate: { _ in }
        )
        .padding()
    }
}
