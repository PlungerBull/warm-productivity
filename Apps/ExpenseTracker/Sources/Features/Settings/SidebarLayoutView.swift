import SwiftUI
import SharedUI

struct SidebarLayoutView: View {
    @Binding var showBankAccounts: Bool
    @Binding var showCategories: Bool
    @Binding var showPeople: Bool
    let onSave: () -> Void

    var body: some View {
        List {
            Section {
                toggleRow(
                    icon: "building.columns",
                    label: "Bank Accounts",
                    isOn: $showBankAccounts
                )
                toggleRow(
                    icon: "tag",
                    label: "Categories",
                    isOn: $showCategories
                )
                toggleRow(
                    icon: "person.2",
                    label: "People",
                    isOn: $showPeople
                )
            } header: {
                Text("Visible Sections")
            } footer: {
                Text("Choose which sections appear in the sidebar.")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Sidebar Layout")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showBankAccounts) { onSave() }
        .onChange(of: showCategories) { onSave() }
        .onChange(of: showPeople) { onSave() }
    }

    private func toggleRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: WPSpacing.sm) {
                Image(systemName: icon)
                    .font(.wpBody)
                    .foregroundStyle(Color.wpPrimary)
                    .frame(width: 24, alignment: .center)
                Text(label)
                    .font(.wpBody)
            }
        }
        .tint(Color.wpPrimary)
    }
}
