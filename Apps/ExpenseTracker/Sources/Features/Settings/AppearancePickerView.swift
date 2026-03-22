import SwiftUI
import SharedUI

struct AppearancePickerView: View {
    let currentTheme: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let themes = [
        ("system", "System"),
        ("light", "Light"),
        ("dark", "Dark"),
    ]

    var body: some View {
        List {
            ForEach(themes, id: \.0) { (value, label) in
                Button {
                    onSelect(value)
                    dismiss()
                } label: {
                    HStack {
                        Text(label)
                            .font(.wpBody)
                            .foregroundStyle(Color.wpTextPrimary)
                        Spacer()
                        if currentTheme == value {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.wpPrimary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
