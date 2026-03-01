import SwiftUI

/// Reusable token-based autocomplete for @category, $account, /person, #hashtag.
/// Placeholder — full implementation during Phase 1 UI.
public struct TokenAutocompleteField: View {
    let placeholder: String

    public init(placeholder: String = "Type to search...") {
        self.placeholder = placeholder
    }

    public var body: some View {
        TextField(placeholder, text: .constant(""))
            .textFieldStyle(.roundedBorder)
    }
}
