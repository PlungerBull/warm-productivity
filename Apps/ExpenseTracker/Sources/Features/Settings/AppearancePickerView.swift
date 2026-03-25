import SwiftUI
import SharedUI

struct AppearancePickerView: View {
    let currentTheme: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let themes: [(value: String, label: String, icon: String)] = [
        ("system", "System", "gear"),
        ("light", "Light", "sun.max"),
        ("dark", "Dark", "moon"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(themes, id: \.value) { theme in
                    Button {
                        onSelect(theme.value)
                        dismiss()
                    } label: {
                        HStack(spacing: WPSpacing.sm) {
                            Image(systemName: theme.icon)
                                .font(.wpBody)
                                .foregroundStyle(Color.wpPrimary)
                                .frame(width: 24, alignment: .center)
                            Text(theme.label)
                                .font(.wpBody)
                                .foregroundStyle(Color.wpTextPrimary)
                            Spacer()
                            if currentTheme == theme.value {
                                Image(systemName: "checkmark")
                                    .font(.wpBody)
                                    .foregroundStyle(Color.wpPrimary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            } footer: {
                Text("System follows your device's appearance setting.")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
