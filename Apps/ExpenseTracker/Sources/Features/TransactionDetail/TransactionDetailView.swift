import SwiftUI
import SharedUI
import SharedModels

struct TransactionDetailView: View {
    @State private var viewModel: TransactionDetailViewModel
    let mode: TransactionDetailMode
    let onDismiss: () -> Void

    @State private var categorySearch: String = ""
    @State private var hashtagSearch: String = ""

    init(viewModel: TransactionDetailViewModel, mode: TransactionDetailMode, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.mode = mode
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                amountSection
                dateSection
                accountSection
                categorySection
                hashtagSection

                if viewModel.showExchangeRate {
                    exchangeRateSection
                }

                notesSection

                if !viewModel.isInbox {
                    reconciliationSection
                }

                deleteSection
            }
            .navigationTitle(viewModel.isInbox ? "Inbox Item" : "Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    confirmationButton
                }
            }
            .alert("Delete Transaction", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.deleteTransaction()
                    onDismiss()
                }
            } message: {
                Text("This transaction will be permanently removed.")
            }
            .task {
                viewModel.load(mode: mode)
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section {
            TextField("Title", text: $viewModel.title)
                .font(.wpBody)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            viewModel.validationErrors.contains(.title) ? Color.wpError : Color.clear,
                            lineWidth: 1
                        )
                )
        }
    }

    private var amountSection: some View {
        Section {
            HStack(spacing: WPSpacing.sm) {
                Button {
                    viewModel.isExpense.toggle()
                } label: {
                    Text(viewModel.isExpense ? "−" : "+")
                        .font(.wpTitle)
                        .foregroundStyle(viewModel.isExpense ? Color.wpExpense : Color.wpIncome)
                        .frame(width: 36, height: 36)
                        .background(
                            (viewModel.isExpense ? Color.wpExpense : Color.wpIncome).opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                }
                .buttonStyle(.plain)

                TextField("0.00", text: $viewModel.amountString)
                    .font(.wpAmountLarge)
                    .keyboardType(.decimalPad)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                viewModel.validationErrors.contains(.amount) ? Color.wpError : Color.clear,
                                lineWidth: 1
                            )
                    )

                if let currency = viewModel.accountCurrency {
                    Text(currency)
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextSecondary)
                }
            }
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                .font(.wpBody)

            HStack(spacing: WPSpacing.xs) {
                dateChip("Yesterday") {
                    if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) {
                        viewModel.date = yesterday
                    }
                }
                dateChip("Today") {
                    viewModel.date = Calendar.current.startOfDay(for: Date())
                }
                dateChip("Tomorrow") {
                    if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) {
                        viewModel.date = tomorrow
                    }
                }
            }
        }
    }

    private var accountSection: some View {
        Section {
            Picker("Account", selection: $viewModel.selectedAccountId) {
                Text("Select account").tag(UUID?.none)
                ForEach(viewModel.accounts, id: \.id) { account in
                    Text("\(account.name) (\(account.currencyCode))")
                        .tag(UUID?.some(account.id))
                }
            }
            .onChange(of: viewModel.selectedAccountId) {
                viewModel.autoPopulateExchangeRate()
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            TokenAutocompleteField(
                text: $categorySearch,
                placeholder: "Search categories...",
                suggestions: filteredCategories,
                onSelect: { suggestion in
                    viewModel.selectedCategoryId = suggestion.id
                    categorySearch = suggestion.text
                },
                onCreate: { name in
                    viewModel.createCategory(name: name)
                    categorySearch = name
                }
            )
            if let categoryId = viewModel.selectedCategoryId,
               let category = viewModel.categories.first(where: { $0.id == categoryId }) {
                HStack {
                    Circle()
                        .fill(Color(hex: category.color))
                        .frame(width: 10, height: 10)
                    Text(category.name)
                        .font(.wpBody)
                    Spacer()
                    Button {
                        viewModel.selectedCategoryId = nil
                        categorySearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.wpTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hashtagSection: some View {
        Section("Hashtags") {
            TokenAutocompleteField(
                text: $hashtagSearch,
                placeholder: "Search hashtags...",
                suggestions: filteredHashtags,
                onSelect: { suggestion in
                    viewModel.selectedHashtagIds.insert(suggestion.id)
                    hashtagSearch = ""
                },
                onCreate: { name in
                    viewModel.createHashtag(name: name)
                    hashtagSearch = ""
                }
            )

            if !viewModel.selectedHashtagIds.isEmpty {
                FlowLayout(spacing: WPSpacing.xs) {
                    ForEach(
                        viewModel.hashtags.filter { viewModel.selectedHashtagIds.contains($0.id) },
                        id: \.id
                    ) { hashtag in
                        hashtagChip(hashtag)
                    }
                }
            }
        }
    }

    private var exchangeRateSection: some View {
        Section("Exchange Rate") {
            HStack {
                Text("\(viewModel.accountCurrency ?? "") → \(viewModel.currencyFormatter.currencyCode)")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextSecondary)
                Spacer()
                TextField("1.0", text: $viewModel.exchangeRate)
                    .font(.wpBody)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $viewModel.descriptionText)
                .font(.wpBody)
                .frame(minHeight: 80)
        }
    }

    private var reconciliationSection: some View {
        Section {
            HStack {
                Text("Reconciliation")
                    .font(.wpBody)
                Spacer()
                Text("Not reconciled")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showDeleteConfirmation = true
            } label: {
                Label("Delete Transaction", systemImage: "trash")
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var confirmationButton: some View {
        if viewModel.isInbox {
            Menu {
                Button {
                    viewModel.save()
                    onDismiss()
                } label: {
                    Label("Save Draft", systemImage: "square.and.arrow.down")
                }
                if viewModel.canPromote {
                    Button {
                        viewModel.promote()
                        onDismiss()
                    } label: {
                        Label("Promote to Ledger", systemImage: "checkmark.circle")
                    }
                }
            } label: {
                Image(systemName: "checkmark")
            }
        } else {
            Button {
                viewModel.save()
                onDismiss()
            } label: {
                Image(systemName: "checkmark")
            }
        }
    }

    // MARK: - Filtered Suggestions

    private var filteredCategories: [AutocompleteSuggestion] {
        guard !categorySearch.isEmpty else { return [] }
        let query = categorySearch.lowercased()
        return viewModel.categories
            .filter { $0.name.lowercased().contains(query) }
            .map { category in
                AutocompleteSuggestion(
                    id: category.id,
                    text: category.name,
                    secondaryText: category.categoryType.rawValue.capitalized,
                    color: Color(hex: category.color)
                )
            }
    }

    private var filteredHashtags: [AutocompleteSuggestion] {
        guard !hashtagSearch.isEmpty else { return [] }
        let query = hashtagSearch.lowercased()
        return viewModel.hashtags
            .filter { $0.name.lowercased().contains(query) && !viewModel.selectedHashtagIds.contains($0.id) }
            .map { hashtag in
                AutocompleteSuggestion(id: hashtag.id, text: hashtag.name)
            }
    }

    // MARK: - Helper Views

    private func dateChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.wpCaption)
                .padding(.horizontal, WPSpacing.sm)
                .padding(.vertical, WPSpacing.xxs)
                .background(Color.wpSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.wpBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func hashtagChip(_ hashtag: ExpenseHashtag) -> some View {
        HStack(spacing: WPSpacing.xxs) {
            Text("#\(hashtag.name)")
                .font(.wpCaption)
            Button {
                viewModel.selectedHashtagIds.remove(hashtag.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.wpIconSmall)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WPSpacing.xs)
        .padding(.vertical, WPSpacing.xxs)
        .background(Color.wpPrimary.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, offsets: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (
            size: CGSize(width: maxWidth, height: currentY + lineHeight),
            offsets: offsets
        )
    }
}
