import SwiftUI
import SharedUI
import SharedModels

struct TransactionsSidebarView: View {
    @Bindable var viewModel: TransactionsSidebarViewModel
    let onSelect: (SidebarDestination) -> Void
    var onSearch: (() -> Void)?

    @State private var accountsExpanded: Bool = true
    @State private var categoriesExpanded: Bool = true
    @State private var hashtagsExpanded: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Header
                header
                    .padding(.horizontal, WPSpacing.md)
                    .padding(.top, WPSpacing.xs)
                    .padding(.bottom, WPSpacing.md)

                // MARK: - Inbox & Ledger Card
                VStack(spacing: 0) {
                    inboxRow
                    cardDivider
                    ledgerRow
                }
                .background(Color.wpSurface)
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                .padding(.horizontal, WPSpacing.md)

                // MARK: - Bank Accounts
                if viewModel.settings?.sidebarShowBankAccounts != false {
                    collapsibleSection(
                        title: "Accounts",
                        isExpanded: $accountsExpanded,
                        onCreate: {
                            viewModel.newItemName = ""
                            viewModel.showCreateAccount = true
                        }
                    ) {
                        if viewModel.bankAccounts.isEmpty {
                            emptyHint("Tap + to add your first account")
                        } else {
                            ForEach(Array(viewModel.bankAccounts.enumerated()), id: \.element.id) { index, account in
                                if index > 0 { cardDivider }
                                symbolRow(
                                    symbol: "$",
                                    color: Color(hex: account.color),
                                    label: account.name,
                                    value: viewModel.currencyFormatter.format(viewModel.accountBalances[account.id] ?? 0),
                                    valueColor: (viewModel.accountBalances[account.id] ?? 0) >= 0 ? Color.wpIncome : Color.wpExpense
                                ) {
                                    onSelect(.bankAccount(id: account.id))
                                }
                                .contextMenu {
                                    Button { viewModel.renamingItemId = account.id; viewModel.renameText = account.name } label: { Label("Rename", systemImage: "pencil") }
                                    Button(role: .destructive) { viewModel.archiveAccount(id: account.id) } label: { Label("Archive", systemImage: "archivebox") }
                                }
                            }
                        }
                    }
                }

                // MARK: - Categories
                if viewModel.settings?.sidebarShowCategories != false {
                    collapsibleSection(
                        title: "Categories",
                        isExpanded: $categoriesExpanded,
                        onCreate: {
                            viewModel.newItemName = ""
                            viewModel.showCreateCategory = true
                        }
                    ) {
                        if viewModel.categories.isEmpty {
                            emptyHint("Tap + to create categories")
                        } else {
                            ForEach(Array(viewModel.categories.enumerated()), id: \.element.id) { index, category in
                                if index > 0 { cardDivider }
                                symbolRow(
                                    symbol: "@",
                                    color: Color(hex: category.color),
                                    label: category.name,
                                    value: viewModel.currencyFormatter.format(viewModel.categorySpend[category.id] ?? 0),
                                    valueColor: Color.wpTextSecondary
                                ) {
                                    onSelect(.category(id: category.id))
                                }
                                .contextMenu {
                                    if !viewModel.isSystemCategory(category) {
                                        Button { viewModel.renamingItemId = category.id; viewModel.renameText = category.name } label: { Label("Rename", systemImage: "pencil") }
                                        Button(role: .destructive) { viewModel.deleteCategory(id: category.id) } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: - Hashtags
                collapsibleSection(
                    title: "Hashtags",
                    isExpanded: $hashtagsExpanded,
                    onCreate: {
                        viewModel.newItemName = ""
                        viewModel.showCreateHashtag = true
                    }
                ) {
                    if viewModel.hashtags.isEmpty {
                        emptyHint("Hashtags appear as you use them")
                    } else {
                        ForEach(Array(viewModel.hashtags.enumerated()), id: \.element.id) { index, hashtag in
                            if index > 0 { cardDivider }
                            symbolRow(
                                symbol: "#",
                                color: Color.wpHashtag,
                                label: hashtag.name
                            ) {
                                onSelect(.hashtag(id: hashtag.id))
                            }
                            .contextMenu {
                                Button { viewModel.renamingItemId = hashtag.id; viewModel.renameText = hashtag.name } label: { Label("Rename", systemImage: "pencil") }
                                Button(role: .destructive) { viewModel.deleteHashtag(id: hashtag.id) } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .sheet(isPresented: $viewModel.showCreateAccount) {
            CreateAccountSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .alert("New Category", isPresented: $viewModel.showCreateCategory) {
            TextField("Category name", text: $viewModel.newItemName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { viewModel.createCategory(name: viewModel.newItemName) }
        }
        .alert("New Hashtag", isPresented: $viewModel.showCreateHashtag) {
            TextField("Hashtag name", text: $viewModel.newItemName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { viewModel.createHashtag(name: viewModel.newItemName) }
        }
        .alert("Rename", isPresented: .init(
            get: { viewModel.renamingItemId != nil },
            set: { if !$0 { viewModel.renamingItemId = nil } }
        )) {
            TextField("New name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) { viewModel.renamingItemId = nil }
            Button("Rename") {
                if let id = viewModel.renamingItemId { performRename(id: id) }
                viewModel.renamingItemId = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Transactions")
                .font(.wpLargeTitle)
                .foregroundStyle(Color.wpTextPrimary)
                .tracking(-0.5)
            Spacer()
            Button(action: { onSearch?() }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.wpTextTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Inbox Row

    private var inboxRow: some View {
        Button { onSelect(.inbox) } label: {
            HStack(spacing: WPSpacing.sm) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.wpPrimary)
                    .frame(width: 28, height: 28)
                Text("Inbox")
                    .font(.wpBody)
                    .foregroundStyle(Color.wpTextPrimary)
                Spacer()
                if viewModel.inboxCount > 0 {
                    Text("\(viewModel.inboxCount)")
                        .font(.wpCaption2.weight(.semibold))
                        .foregroundStyle(Color.wpOnPrimary)
                        .padding(.horizontal, WPBadgeStyle.horizontalPadding)
                        .frame(minWidth: WPBadgeStyle.minWidth, minHeight: WPBadgeStyle.height)
                        .background(Color.wpPrimary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, WPSpacing.md)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ledger Row

    private var ledgerRow: some View {
        Button { onSelect(.ledger) } label: {
            HStack(spacing: WPSpacing.sm) {
                Image(systemName: "creditcard")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.wpPrimary)
                    .frame(width: 28, height: 28)
                Text("Ledger")
                    .font(.wpBody)
                    .foregroundStyle(Color.wpTextPrimary)
                Spacer()
            }
            .padding(.horizontal, WPSpacing.md)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Symbol Row (accounts, categories, hashtags)

    private func symbolRow(
        symbol: String,
        color: Color,
        label: String,
        value: String? = nil,
        valueColor: Color = Color.wpTextSecondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: WPSpacing.sm) {
                SymbolBadge(symbol: symbol, color: color)
                Text(label)
                    .font(.wpCallout)
                    .foregroundStyle(Color.wpTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: WPSpacing.xs)
                if let value {
                    Text(value)
                        .font(.wpAmountCompact)
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, WPSpacing.md)
            .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Collapsible Section

    private func collapsibleSection<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        onCreate: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: WPSpacing.xs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    HStack(spacing: WPSpacing.xxs) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.wpTextTertiary)
                            .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))

                        Text(title.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.wpTextTertiary)
                            .tracking(0.6)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.wpTextTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, WPSpacing.md)
            .padding(.top, WPSpacing.lg)
            .padding(.bottom, WPSpacing.xxs)

            // Card with rows
            if isExpanded.wrappedValue {
                VStack(spacing: 0) {
                    content()
                }
                .background(Color.wpSurface)
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                .padding(.horizontal, WPSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Empty Hint

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.wpCaption)
            .foregroundStyle(Color.wpTextTertiary)
            .padding(.horizontal, WPSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
    }

    // MARK: - Card Divider

    private var cardDivider: some View {
        Rectangle()
            .fill(Color.wpBorder)
            .frame(height: 0.5)
            .padding(.leading, WPSpacing.md + WPSymbolBadgeStyle.size + WPSpacing.sm)
    }

    // MARK: - Helpers

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
                        viewModel.createAccount(name: viewModel.newItemName, currencyCode: viewModel.newAccountCurrency)
                        dismiss()
                    }
                    .disabled(viewModel.newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
