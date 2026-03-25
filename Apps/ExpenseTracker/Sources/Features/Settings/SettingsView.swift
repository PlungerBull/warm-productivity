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
                    NavigationLink {
                        // Future: profile detail
                        EmptyView()
                    } label: {
                        HStack(spacing: WPSpacing.md) {
                            initialsAvatar
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.user?.displayName ?? "User")
                                    .font(.wpHeadline)
                                    .foregroundStyle(Color.wpTextPrimary)
                                if let email = viewModel.user?.email {
                                    Text(email)
                                        .font(.wpCaption)
                                        .foregroundStyle(Color.wpTextSecondary)
                                }
                            }
                        }
                        .padding(.vertical, WPSpacing.xxs)
                    }
                }

                // General section
                Section {
                    NavigationLink {
                        CurrencyPickerView(
                            currencies: viewModel.currencies,
                            selectedCode: viewModel.settings?.mainCurrency ?? "USD",
                            onSelect: { code in viewModel.updateCurrency(code) }
                        )
                    } label: {
                        settingsRow(
                            icon: "banknote",
                            label: "Home Currency",
                            value: viewModel.settings?.mainCurrency ?? "USD"
                        )
                    }

                    settingsRow(
                        icon: "building.columns",
                        label: "Default Account",
                        value: "Chase"
                    )
                } header: {
                    Text("General")
                }

                // Display section
                Section {
                    NavigationLink {
                        AppearancePickerView(
                            currentTheme: viewModel.settings?.theme ?? "system",
                            onSelect: { theme in viewModel.updateTheme(theme) }
                        )
                    } label: {
                        settingsRow(
                            icon: "circle.lefthalf.filled",
                            label: "Appearance",
                            value: viewModel.settings?.theme.capitalized ?? "System"
                        )
                    }
                } header: {
                    Text("Display")
                }

                // Data section
                Section {
                    NavigationLink {
                        CSVImportView(viewModel: makeCSVImportViewModel())
                    } label: {
                        Label {
                            Text("Import CSV")
                                .font(.wpBody)
                        } icon: {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(Color.wpPrimary)
                        }
                    }

                    Label {
                        Text("Export Data")
                            .font(.wpBody)
                            .foregroundStyle(Color.wpTextTertiary)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.wpTextTertiary)
                    }
                } header: {
                    Text("Data")
                }

                // Sign Out section
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .font(.wpBody)
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
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

    // MARK: - Components

    private var initialsAvatar: some View {
        let name = viewModel.user?.displayName ?? "U"
        let components = name.split(separator: " ")
        let firstInitial = components.first.map { String($0.prefix(1)) } ?? "U"
        let lastInitial = components.count > 1 ? (components.last.map { String($0.prefix(1)) } ?? "") : ""
        let initials = (firstInitial + lastInitial).uppercased()

        return Text(initials)
            .font(.wpHeadline)
            .foregroundStyle(Color.wpPrimary)
            .frame(width: WPSize.avatarMedium, height: WPSize.avatarMedium)
            .background(Color.wpPrimary.opacity(0.1))
            .clipShape(Circle())
    }

    private var startOfWeekLabel: String {
        guard let dow = viewModel.settings?.startOfWeek else { return "Monday" }
        let symbols = Calendar.current.weekdaySymbols
        let index = dow % 7
        return symbols[index]
    }

    private func settingsRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: WPSpacing.sm) {
            Image(systemName: icon)
                .font(.wpBody)
                .foregroundStyle(Color.wpPrimary)
                .frame(width: 24, alignment: .center)
            Text(label)
                .font(.wpBody)
            Spacer()
            Text(value)
                .font(.wpBody)
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
