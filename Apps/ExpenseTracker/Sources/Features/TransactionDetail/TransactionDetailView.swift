import SwiftUI
import SharedUI
import SharedModels

struct TransactionDetailView: View {
    @State private var viewModel: TransactionDetailViewModel
    let mode: TransactionDetailMode
    let onDismiss: () -> Void

    @State private var categorySearch: String = ""
    @State private var hashtagSearch: String = ""
    @State private var showDatePicker: Bool = false
    @State private var showAccountPicker: Bool = false
    @State private var showCategoryPicker: Bool = false
    @State private var showHashtagPicker: Bool = false

    init(viewModel: TransactionDetailViewModel, mode: TransactionDetailMode, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.mode = mode
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            sheetContent
            Spacer(minLength: 0)
            if viewModel.canPromote {
                promoteButton
            }
            bottomToolbar
        }
        .background(Color.wpBackground)
        .alert("Delete Transaction", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteTransaction()
                onDismiss()
            }
        } message: {
            Text("This transaction will be permanently removed.")
        }
        .sheet(isPresented: $showAccountPicker) {
            accountPickerSheet
        }
        .sheet(isPresented: $showCategoryPicker) {
            categoryPickerSheet
        }
        .sheet(isPresented: $showHashtagPicker) {
            hashtagPickerSheet
        }
        .task {
            viewModel.load(mode: mode)
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: WPContentSheetStyle.handleCornerRadius)
            .fill(Color.wpBorder)
            .frame(
                width: WPContentSheetStyle.handleWidth,
                height: WPContentSheetStyle.handleHeight
            )
            .padding(.top, WPSpacing.sm)
            .padding(.bottom, WPSpacing.sm)
    }

    // MARK: - Sheet Content

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            dateLine
                .padding(.top, WPSpacing.sm)

            titleField
                .padding(.top, WPSpacing.xs)

            amountField
                .padding(.top, WPSpacing.xxs)

            if viewModel.showExchangeRate {
                exchangeRateLine
                    .padding(.top, WPSpacing.xs)
            }

            descriptionField
                .padding(.top, WPSpacing.md)

            tagsArea
                .padding(.top, WPSpacing.lg)
        }
        .padding(.horizontal, WPSpacing.md)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Button {
                showAccountPicker = true
            } label: {
                HStack(spacing: WPSpacing.xxs) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.wpSuccess)
                    Text(selectedAccountName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.wpSuccess)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.wpTextTertiary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: WPSpacing.lg) {
                Button {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.wpTextTertiary)
                }
                .buttonStyle(.plain)

                Menu {
                    if viewModel.isInbox {
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
                    } else {
                        Button {
                            viewModel.save()
                            onDismiss()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                    }
                    Button(role: .cancel) {
                        onDismiss()
                    } label: {
                        Label("Discard Changes", systemImage: "xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.wpTextTertiary)
                }
            }
        }
    }

    // MARK: - Date Line

    private var dateLine: some View {
        Button {
            showDatePicker.toggle()
        } label: {
            HStack(spacing: WPSpacing.xxs) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wpPrimary)
                Text(formattedDate)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wpPrimary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker) {
            DatePicker(
                "Date",
                selection: $viewModel.date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Title

    private var titleField: some View {
        TextField("Untitled transaction", text: $viewModel.title)
            .font(.system(size: WPContentSheetStyle.titleFontSize, weight: .semibold))
            .foregroundStyle(Color.wpTextPrimary)
            .textFieldStyle(.plain)
            .overlay(alignment: .leading) {
                if viewModel.validationErrors.contains(.title) {
                    Rectangle()
                        .fill(Color.wpError)
                        .frame(width: 2)
                        .offset(x: -WPSpacing.xs)
                }
            }
    }

    // MARK: - Amount

    private var amountField: some View {
        HStack(spacing: WPSpacing.xxs) {
            Button {
                viewModel.isExpense.toggle()
            } label: {
                Text(viewModel.isExpense ? "-" : "+")
                    .font(.system(size: WPContentSheetStyle.amountFontSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(amountColor)
            }
            .buttonStyle(.plain)

            if let currency = viewModel.accountCurrency {
                Text(currencySymbol(for: currency))
                    .font(.system(size: WPContentSheetStyle.amountFontSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(amountColor)
            }

            TextField("0.00", text: $viewModel.amountString)
                .font(.system(size: WPContentSheetStyle.amountFontSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(amountColor)
                .textFieldStyle(.plain)
                .keyboardType(.decimalPad)
        }
        .overlay(alignment: .leading) {
            if viewModel.validationErrors.contains(.amount) {
                Rectangle()
                    .fill(Color.wpError)
                    .frame(width: 2)
                    .offset(x: -WPSpacing.xs)
            }
        }
    }

    // MARK: - Exchange Rate

    private var exchangeRateLine: some View {
        HStack(spacing: WPSpacing.xxs) {
            Text("\(viewModel.accountCurrency ?? "") \u{2192} \(viewModel.currencyFormatter.currencyCode)")
                .font(.wpCaption)
                .foregroundStyle(Color.wpTextTertiary)
            TextField("1.0", text: $viewModel.exchangeRate)
                .font(.wpCaption)
                .foregroundStyle(Color.wpTextSecondary)
                .textFieldStyle(.plain)
                .keyboardType(.decimalPad)
                .frame(width: 60)
        }
    }

    // MARK: - Description

    private var descriptionField: some View {
        TextField("Add a description...", text: $viewModel.descriptionText, axis: .vertical)
            .font(.wpCallout)
            .foregroundStyle(
                viewModel.descriptionText.isEmpty ? Color.wpTextTertiary : Color.wpTextPrimary
            )
            .textFieldStyle(.plain)
            .lineLimit(1...4)
    }

    // MARK: - Tags Area

    private var tagsArea: some View {
        FlowLayout(spacing: WPSpacing.xs) {
            if let category = selectedCategory {
                Button {
                    showCategoryPicker = true
                } label: {
                    Text("@\(category.name)")
                        .wpTagChip(color: Color(hex: category.color))
                }
                .buttonStyle(.plain)
            }

            ForEach(selectedHashtags, id: \.id) { hashtag in
                Button {
                    showHashtagPicker = true
                } label: {
                    Text("#\(hashtag.name)")
                        .wpTagChip(color: Color.wpHashtag)
                }
                .buttonStyle(.plain)
            }

            if selectedCategory == nil {
                Button {
                    showCategoryPicker = true
                } label: {
                    Text("+ category")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.wpTextTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.wpBorder.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Promote Button (Inbox Only)

    private var promoteButton: some View {
        Button {
            viewModel.promote()
            onDismiss()
        } label: {
            HStack(spacing: WPSpacing.xs) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Promote to Ledger")
                    .font(.wpHeadline)
            }
            .foregroundStyle(Color.wpOnPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, WPSpacing.md)
            .background(Color.wpPrimary)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, WPSpacing.md)
        .padding(.bottom, WPSpacing.xs)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: WPSpacing.lg) {
            Button {
                showCategoryPicker = true
            } label: {
                Image(systemName: "tag")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.wpTextTertiary)
            }
            .buttonStyle(.plain)

            Button {
                showHashtagPicker = true
            } label: {
                Image(systemName: "number")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.wpTextTertiary)
            }
            .buttonStyle(.plain)

            Button {} label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.wpTextTertiary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.save()
                onDismiss()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.wpPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WPSpacing.lg)
        .padding(.vertical, WPSpacing.sm)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.wpBorder)
                .frame(height: 0.5)
        }
    }

    // MARK: - Account Picker Sheet

    private var accountPickerSheet: some View {
        NavigationStack {
            List(viewModel.accounts, id: \.id) { account in
                Button {
                    viewModel.selectedAccountId = account.id
                    viewModel.autoPopulateExchangeRate()
                    showAccountPicker = false
                } label: {
                    HStack {
                        Text(account.name)
                            .font(.wpBody)
                            .foregroundStyle(Color.wpTextPrimary)
                        Text(account.currencyCode)
                            .font(.wpCaption)
                            .foregroundStyle(Color.wpTextSecondary)
                        Spacer()
                        if viewModel.selectedAccountId == account.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.wpPrimary)
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showAccountPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Category Picker Sheet

    private var categoryPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TokenAutocompleteField(
                    text: $categorySearch,
                    placeholder: "Search categories...",
                    suggestions: filteredCategories,
                    onSelect: { suggestion in
                        viewModel.selectedCategoryId = suggestion.id
                        categorySearch = ""
                        showCategoryPicker = false
                    },
                    onCreate: { name in
                        viewModel.createCategory(name: name)
                        categorySearch = ""
                        showCategoryPicker = false
                    }
                )
                .padding(.horizontal, WPSpacing.md)
                .padding(.top, WPSpacing.sm)

                List(viewModel.categories, id: \.id) { category in
                    Button {
                        viewModel.selectedCategoryId = category.id
                        showCategoryPicker = false
                    } label: {
                        HStack(spacing: WPSpacing.xs) {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 10, height: 10)
                            Text(category.name)
                                .font(.wpBody)
                                .foregroundStyle(Color.wpTextPrimary)
                            Spacer()
                            if viewModel.selectedCategoryId == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.wpPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showCategoryPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.selectedCategoryId != nil {
                        Button {
                            viewModel.selectedCategoryId = nil
                            categorySearch = ""
                            showCategoryPicker = false
                        } label: {
                            Text("Clear")
                                .foregroundStyle(Color.wpError)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Hashtag Picker Sheet

    private var hashtagPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                .padding(.horizontal, WPSpacing.md)
                .padding(.top, WPSpacing.sm)

                List {
                    if !viewModel.selectedHashtagIds.isEmpty {
                        Section("Selected") {
                            ForEach(selectedHashtags, id: \.id) { hashtag in
                                Button {
                                    viewModel.selectedHashtagIds.remove(hashtag.id)
                                } label: {
                                    HStack {
                                        Text("#\(hashtag.name)")
                                            .font(.wpBody)
                                            .foregroundStyle(Color.wpHashtag)
                                        Spacer()
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.wpTextTertiary)
                                    }
                                }
                            }
                        }
                    }

                    Section("All") {
                        ForEach(
                            viewModel.hashtags.filter { !viewModel.selectedHashtagIds.contains($0.id) },
                            id: \.id
                        ) { hashtag in
                            Button {
                                viewModel.selectedHashtagIds.insert(hashtag.id)
                            } label: {
                                Text("#\(hashtag.name)")
                                    .font(.wpBody)
                                    .foregroundStyle(Color.wpTextPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hashtags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showHashtagPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
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

    // MARK: - Computed Helpers

    private var selectedAccountName: String {
        guard let accountId = viewModel.selectedAccountId,
              let account = viewModel.accounts.first(where: { $0.id == accountId }) else {
            return "No account"
        }
        return account.name
    }

    private var selectedCategory: ExpenseCategory? {
        guard let categoryId = viewModel.selectedCategoryId else { return nil }
        return viewModel.categories.first { $0.id == categoryId }
    }

    private var selectedHashtags: [ExpenseHashtag] {
        viewModel.hashtags.filter { viewModel.selectedHashtagIds.contains($0.id) }
    }

    private var amountColor: Color {
        viewModel.isExpense ? Color.wpExpense : Color.wpIncome
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(viewModel.date) {
            return "Today, \(shortDateString)"
        } else if calendar.isDateInYesterday(viewModel.date) {
            return "Yesterday, \(shortDateString)"
        } else if calendar.isDateInTomorrow(viewModel.date) {
            return "Tomorrow, \(shortDateString)"
        }
        return shortDateString
    }

    private var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: viewModel.date)
    }

    private func currencySymbol(for code: String) -> String {
        let locale = Locale.availableIdentifiers
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? "$"
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
