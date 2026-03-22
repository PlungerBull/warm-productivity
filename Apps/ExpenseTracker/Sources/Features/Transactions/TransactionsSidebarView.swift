import SwiftUI
import SharedUI
import SharedModels

struct TransactionsSidebarView: View {
    @Bindable var viewModel: TransactionsSidebarViewModel
    @Binding var selection: SidebarDestination?

    var body: some View {
        List(selection: $selection) {
            // Pinned section
            Section {
                Label("Inbox", systemImage: "tray.fill")
                    .tag(SidebarDestination.inbox)
                Label("Ledger", systemImage: "list.bullet")
                    .tag(SidebarDestination.ledger)
            }

            // Bank Accounts
            if viewModel.settings?.sidebarShowBankAccounts != false {
                Section {
                    DisclosureGroup {
                        ForEach(viewModel.bankAccounts, id: \.id) { account in
                            accountRow(account)
                                .tag(SidebarDestination.bankAccount(id: account.id))
                        }
                        .onMove { source, destination in
                            viewModel.moveAccounts(from: source, to: destination)
                        }
                    } label: {
                        sectionHeader("Bank Accounts") {
                            viewModel.newItemName = ""
                            viewModel.showCreateAccount = true
                        }
                    }
                }
            }

            // Categories
            if viewModel.settings?.sidebarShowCategories != false {
                Section {
                    DisclosureGroup {
                        ForEach(viewModel.categories, id: \.id) { category in
                            categoryRow(category)
                                .tag(SidebarDestination.category(id: category.id))
                        }
                        .onMove { source, destination in
                            viewModel.moveCategories(from: source, to: destination)
                        }
                    } label: {
                        sectionHeader("Categories") {
                            viewModel.newItemName = ""
                            viewModel.showCreateCategory = true
                        }
                    }
                }
            }

            // Hashtags
            Section {
                DisclosureGroup {
                    ForEach(viewModel.hashtags, id: \.id) { hashtag in
                        hashtagRow(hashtag)
                            .tag(SidebarDestination.hashtag(id: hashtag.id))
                    }
                    .onMove { source, destination in
                        viewModel.moveHashtags(from: source, to: destination)
                    }
                } label: {
                    sectionHeader("Hashtags") {
                        viewModel.newItemName = ""
                        viewModel.showCreateHashtag = true
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Transactions")
        .sheet(isPresented: $viewModel.showCreateAccount) {
            CreateAccountSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .alert("New Category", isPresented: $viewModel.showCreateCategory) {
            TextField("Category name", text: $viewModel.newItemName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                viewModel.createCategory(name: viewModel.newItemName)
            }
        }
        .alert("New Hashtag", isPresented: $viewModel.showCreateHashtag) {
            TextField("Hashtag name", text: $viewModel.newItemName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                viewModel.createHashtag(name: viewModel.newItemName)
            }
        }
        .alert("Rename", isPresented: .init(
            get: { viewModel.renamingItemId != nil },
            set: { if !$0 { viewModel.renamingItemId = nil } }
        )) {
            TextField("New name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) {
                viewModel.renamingItemId = nil
            }
            Button("Rename") {
                if let id = viewModel.renamingItemId {
                    performRename(id: id)
                }
                viewModel.renamingItemId = nil
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, onCreate: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                onCreate()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.wpPrimary)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Row Views

    private func accountRow(_ account: ExpenseBankAccount) -> some View {
        HStack {
            Text(account.name)
                .font(.wpBody)
            Spacer()
            let balance = viewModel.accountBalances[account.id] ?? 0
            Text(viewModel.currencyFormatter.format(balance))
                .font(.wpCaption)
                .foregroundStyle(balance >= 0 ? Color.wpSuccess : Color.wpError)
        }
        .contextMenu {
            Button {
                viewModel.renamingItemId = account.id
                viewModel.renameText = account.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.archiveAccount(id: account.id)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    private func categoryRow(_ category: ExpenseCategory) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 10, height: 10)
            Text(category.name)
                .font(.wpBody)
            Spacer()
            let spend = viewModel.categorySpend[category.id] ?? 0
            Text(viewModel.currencyFormatter.format(spend))
                .font(.wpCaption)
                .foregroundStyle(Color.wpTextSecondary)
        }
        .contextMenu {
            if !viewModel.isSystemCategory(category) {
                Button {
                    viewModel.renamingItemId = category.id
                    viewModel.renameText = category.name
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    viewModel.deleteCategory(id: category.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func hashtagRow(_ hashtag: ExpenseHashtag) -> some View {
        HStack {
            Text("#\(hashtag.name)")
                .font(.wpBody)
            Spacer()
        }
        .contextMenu {
            Button {
                viewModel.renamingItemId = hashtag.id
                viewModel.renameText = hashtag.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.deleteHashtag(id: hashtag.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Rename Helper

    private func performRename(id: UUID) {
        if viewModel.bankAccounts.contains(where: { $0.id == id }) {
            viewModel.renameAccount(id: id, name: viewModel.renameText)
        } else if viewModel.categories.contains(where: { $0.id == id }) {
            viewModel.renameCategory(id: id, name: viewModel.renameText)
        } else if viewModel.hashtags.contains(where: { $0.id == id }) {
            viewModel.renameHashtag(id: id, name: viewModel.renameText)
        }
    }
}

// MARK: - Create Account Sheet

private struct CreateAccountSheet: View {
    @Bindable var viewModel: TransactionsSidebarViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Name") {
                    TextField("e.g. Chase, BCP PEN...", text: $viewModel.newItemName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section("Currency") {
                    Picker("Currency", selection: $viewModel.newAccountCurrency) {
                        ForEach(viewModel.currencies, id: \.code) { currency in
                            Text("\(currency.flag ?? "") \(currency.code) — \(currency.name)")
                                .tag(currency.code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle("New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createAccount(
                            name: viewModel.newItemName,
                            currencyCode: viewModel.newAccountCurrency
                        )
                        dismiss()
                    }
                    .disabled(viewModel.newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
