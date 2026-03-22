import SwiftUI
import SwiftData
import SharedUI
import SharedModels

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    let onSignOut: () async -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section {
                    HStack(spacing: WPSpacing.md) {
                        initialsAvatar
                        VStack(alignment: .leading, spacing: WPSpacing.xxs) {
                            Text(viewModel.user?.displayName ?? "User")
                                .font(.wpHeadline)
                            if let email = viewModel.user?.email {
                                Text(email)
                                    .font(.wpCaption)
                                    .foregroundStyle(Color.wpTextSecondary)
                            }
                        }
                    }
                    .padding(.vertical, WPSpacing.xs)

                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // General section
                Section("General") {
                    NavigationLink {
                        CurrencyPickerView(
                            currencies: viewModel.currencies,
                            selectedCode: viewModel.settings?.mainCurrency ?? "USD",
                            onSelect: { code in viewModel.updateCurrency(code) }
                        )
                    } label: {
                        settingsRow("Main Currency", value: viewModel.settings?.mainCurrency ?? "USD")
                    }

                    NavigationLink {
                        AppearancePickerView(
                            currentTheme: viewModel.settings?.theme ?? "system",
                            onSelect: { theme in viewModel.updateTheme(theme) }
                        )
                    } label: {
                        settingsRow("Theme", value: viewModel.settings?.theme.capitalized ?? "System")
                    }

                    settingsRow("Start of Week", value: startOfWeekLabel)
                    settingsRow("Transaction Sort", value: viewModel.settings?.transactionSortPreference.capitalized ?? "Date")
                }

                // Display section
                Section("Display") {
                    NavigationLink {
                        SidebarLayoutView(
                            showBankAccounts: $viewModel.showBankAccounts,
                            showCategories: $viewModel.showCategories,
                            showPeople: $viewModel.showPeople,
                            onSave: { viewModel.saveSidebarLayout() }
                        )
                    } label: {
                        Label("Sidebar Layout", systemImage: "sidebar.squares.left")
                    }
                }

                // Data section
                Section("Data") {
                    NavigationLink {
                        CSVImportView(viewModel: makeCSVImportViewModel())
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Color.wpTextTertiary)
                }

                // About section
                Section("About") {
                    settingsRow("Version", value: viewModel.appVersion)
                }
            }
            .navigationTitle("Settings")
            .task {
                viewModel.loadSettings()
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task { await onSignOut() }
                }
            } message: {
                Text("Your local data will be kept and synced on next sign-in.")
            }
        }
    }

    private var initialsAvatar: some View {
        let name = viewModel.user?.displayName ?? "U"
        let components = name.split(separator: " ")
        let firstInitial = components.first.map { String($0.prefix(1)) } ?? "U"
        let lastInitial = components.count > 1 ? (components.last.map { String($0.prefix(1)) } ?? "") : ""
        let initials = (firstInitial + lastInitial).uppercased()

        return Text(initials)
            .font(.wpTitle)
            .foregroundStyle(Color.wpOnPrimary)
            .frame(width: WPSize.avatarMedium, height: WPSize.avatarMedium)
            .background(Color.wpPrimary)
            .clipShape(Circle())
    }

    private var startOfWeekLabel: String {
        guard let dow = viewModel.settings?.startOfWeek else { return "Monday" }
        let symbols = Calendar.current.weekdaySymbols
        let index = dow % 7
        return symbols[index]
    }

    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(Color.wpTextSecondary)
        }
    }

    private func makeCSVImportViewModel() -> CSVImportViewModel {
        CSVImportViewModel(
            transactionRepository: TransactionRepository(modelContext: modelContext),
            categoryRepository: CategoryRepository(modelContext: modelContext),
            bankAccountRepository: BankAccountRepository(modelContext: modelContext),
            hashtagRepository: HashtagRepository(modelContext: modelContext),
            transactionHashtagRepository: TransactionHashtagRepository(modelContext: modelContext),
            noteEntryRepository: NoteEntryRepository(modelContext: modelContext),
            entityLinkRepository: EntityLinkRepository(modelContext: modelContext),
            userSettingsRepository: UserSettingsRepository(modelContext: modelContext),
            userId: viewModel.userId
        )
    }
}
