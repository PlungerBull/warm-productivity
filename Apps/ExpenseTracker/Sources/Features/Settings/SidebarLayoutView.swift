import SwiftUI
import SharedUI

struct SidebarLayoutView: View {
    @Binding var showBankAccounts: Bool
    @Binding var showCategories: Bool
    @Binding var showPeople: Bool
    let onSave: () -> Void

    var body: some View {
        List {
            Section("Visible Sections") {
                Toggle("Bank Accounts", isOn: $showBankAccounts)
                    .font(.wpBody)
                Toggle("Categories", isOn: $showCategories)
                    .font(.wpBody)
                Toggle("People", isOn: $showPeople)
                    .font(.wpBody)
            }
        }
        .navigationTitle("Sidebar Layout")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showBankAccounts) { onSave() }
        .onChange(of: showCategories) { onSave() }
        .onChange(of: showPeople) { onSave() }
    }
}
