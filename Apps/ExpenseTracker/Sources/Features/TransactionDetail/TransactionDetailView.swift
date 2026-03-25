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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum DetailFocusField: Hashable {
        case title, amount, note
    }
    @FocusState private var focusedField: DetailFocusField?

    private var isCompact: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private var isNoteEditing: Bool {
        focusedField == .note
    }

    init(viewModel: TransactionDetailViewModel, mode: TransactionDetailMode, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.mode = mode
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetContent
            bottomBar
        }
        .background(.background)
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

    // MARK: - Sheet Content

    private var sheetContent: some View {
        VStack(spacing: 0) {
            dragHandle
            heroSection
            pillsSection
            sectionDivider
            ScrollView {
                VStack(spacing: WPSpacing.sm) {
                    detailsGrid
                    noteCard
                }
                .padding(.horizontal, WPSpacing.md)
                .padding(.vertical, WPSpacing.sm)
            }
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        Group {
            if focusedField == nil {
                RoundedRectangle(cornerRadius: WPContentSheetStyle.handleCornerRadius)
                    .fill(Color.wpTextTertiary.opacity(0.4))
                    .frame(width: WPContentSheetStyle.handleWidth, height: WPContentSheetStyle.handleHeight)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: WPSpacing.xxs) {
            // Title
            TextField("Untitled transaction", text: $viewModel.title)
                .font(.system(size: isCompact ? WPContentSheetStyle.compactTitleFontSize : WPContentSheetStyle.heroTitleFontSize, weight: .bold))
                .foregroundStyle(Color.wpTextPrimary)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .title)
                .overlay(alignment: .leading) {
                    if viewModel.validationErrors.contains(.title) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.wpError)
                            .frame(width: 2)
                            .offset(x: -WPSpacing.xs)
                    }
                }

            // Amount
            HStack(spacing: 0) {
                // Sign toggle
                Button {
                    viewModel.isExpense.toggle()
                } label: {
                    Text(viewModel.isExpense ? "\u{2212}" : "+")
                        .font(.system(size: isCompact ? WPContentSheetStyle.compactAmountFontSize : WPContentSheetStyle.heroAmountFontSize, weight: .bold).monospacedDigit())
                        .foregroundStyle(amountColor)
                }
                .buttonStyle(.plain)
                .contentTransition(.numericText())

                // Currency code (superscript)
                if let currency = viewModel.accountCurrency {
                    Text(currency)
                        .font(.system(size: (isCompact ? WPContentSheetStyle.compactAmountFontSize : WPContentSheetStyle.heroAmountFontSize) * 0.5, weight: .bold))
                        .foregroundStyle(Color.wpTextTertiary)
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                }

                // Amount field
                TextField("0.00", text: $viewModel.amountString)
                    .font(.system(size: isCompact ? WPContentSheetStyle.compactAmountFontSize : WPContentSheetStyle.heroAmountFontSize, weight: .bold).monospacedDigit())
                    .foregroundStyle(amountColor)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
            }
            .overlay(alignment: .leading) {
                if viewModel.validationErrors.contains(.amount) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.wpError)
                        .frame(width: 2)
                        .offset(x: -WPSpacing.xs)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WPSpacing.md)
        .padding(.top, WPSpacing.sm)
        .padding(.bottom, WPSpacing.sm)
    }

    // MARK: - Pills Section

    private var pillsSection: some View {
        WPHorizontalPillScroll {
            // Date pill
            Button { showDatePicker.toggle() } label: {
                HStack(spacing: WPSpacing.xxs) {
                    Image(systemName: "calendar")
                        .font(.wpCaption)
                    Text(formattedDate)
                        .font(.system(size: 13, weight: .medium))
                }
                .wpToolbarPill(state: .selected, color: Color.wpTextSecondary)
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

            // Category pill
            Button { showCategoryPicker = true } label: {
                if let category = selectedCategory {
                    HStack(spacing: WPSpacing.xxs) {
                        Circle().fill(Color(hex: category.color)).frame(width: 7, height: 7)
                        Text(category.name).font(.system(size: 13, weight: .medium))
                    }
                    .wpToolbarPill(state: .selected, color: Color(hex: category.color))
                } else {
                    HStack(spacing: WPSpacing.xxs) {
                        Image(systemName: "tag").font(.wpCaption)
                        Text("Category").font(.system(size: 13, weight: .medium))
                    }
                    .wpToolbarPill(state: .missing, color: Color.wpWarning)
                }
            }
            .buttonStyle(.plain)

            // Account pill
            Button { showAccountPicker = true } label: {
                HStack(spacing: WPSpacing.xxs) {
                    Image(systemName: "building.columns").font(.wpCaption)
                    Text(selectedAccountName).font(.system(size: 13, weight: .medium))
                }
                .wpToolbarPill(
                    state: viewModel.selectedAccountId != nil ? .selected : .missing,
                    color: Color.wpSuccess
                )
            }
            .buttonStyle(.plain)

            // Hashtag pills — one per hashtag
            ForEach(selectedHashtags, id: \.id) { hashtag in
                Button { showHashtagPicker = true } label: {
                    Text("#\(hashtag.name)")
                        .font(.system(size: 13, weight: .medium))
                        .wpToolbarPill(state: .selected, color: Color.wpHashtag)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.wpBorder.opacity(0.3))
            .frame(height: 0.5)
            .padding(.horizontal, WPSpacing.lg)
            .padding(.top, WPSpacing.sm)
    }

    // MARK: - Details Grid

    private var detailsGrid: some View {
        Grid(horizontalSpacing: 0.5, verticalSpacing: 0.5) {
            GridRow {
                detailCell(label: "TYPE", value: viewModel.isExpense ? "Expense" : "Income")
                detailCell(label: "STATUS", valueView: statusBadge)
            }
            GridRow {
                if viewModel.showExchangeRate {
                    detailCell(label: "EXCHANGE", valueView: exchangeRateCell)
                    detailCell(label: "HOME AMOUNT", valueView: homeAmountView)
                } else {
                    detailCell(label: "SOURCE", value: viewModel.isInbox ? "Inbox" : "Ledger")
                    detailCell(label: "CLEARED", valueView: clearedBadge)
                }
            }
        }
        .background(Color.wpBorder.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
    }

    private func detailCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: WPSpacing.xxs) {
            Text(label)
                .font(.wpCaption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.wpTextTertiary)
            Text(value)
                .font(.wpCallout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.wpTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WPSpacing.sm)
        .background(Color.wpSurface)
    }

    private func detailCell<V: View>(label: String, valueView: V) -> some View {
        VStack(alignment: .leading, spacing: WPSpacing.xxs) {
            Text(label)
                .font(.wpCaption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.wpTextTertiary)
            valueView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WPSpacing.sm)
        .background(Color.wpSurface)
    }

    private var statusBadge: some View {
        HStack(spacing: WPSpacing.xxs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.wpCaption)
            Text("Cleared")
                .font(.wpCallout)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.wpSuccess)
    }

    private var clearedBadge: some View {
        HStack(spacing: WPSpacing.xxs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.wpCaption)
            Text("Cleared")
                .font(.wpCallout)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.wpSuccess)
    }

    private var exchangeRateCell: some View {
        HStack(spacing: WPSpacing.xxs) {
            Text("\(viewModel.accountCurrency ?? "") \u{2192} \(viewModel.currencyFormatter.currencyCode)")
                .font(.wpCallout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.wpTextPrimary)
            TextField("1.0", text: $viewModel.exchangeRate)
                .font(.wpCallout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.wpTextSecondary)
                .textFieldStyle(.plain)
                .keyboardType(.decimalPad)
                .frame(width: 60)
        }
    }

    private var homeAmountView: some View {
        Text(formattedHomeAmount)
            .font(.wpCallout)
            .fontWeight(.semibold)
            .foregroundStyle(viewModel.isExpense ? Color.wpExpense : Color.wpIncome)
    }

    private var formattedHomeAmount: String {
        guard let amountCents = viewModel.parsedAmountCents,
              let rateValue = Double(viewModel.exchangeRate),
              rateValue > 0 else {
            return "\u{2014}"
        }
        let homeCents = Double(abs(amountCents)) * rateValue / 100.0
        let sign = viewModel.isExpense ? "\u{2212}" : "+"
        return "\(sign)\(viewModel.currencyFormatter.currencyCode)\(String(format: "%.2f", homeCents))"
    }

    // MARK: - Note Card

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: WPSpacing.xs) {
            // Header
            HStack(spacing: WPSpacing.xxs) {
                Image(systemName: "doc.text")
                    .font(.wpCaption)
                Text("NOTE")
                    .font(.wpCaption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(isNoteEditing ? Color.wpPrimary : Color.wpTextTertiary)

            // Text field
            TextField("Add a note...", text: $viewModel.descriptionText, axis: .vertical)
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextPrimary)
                .textFieldStyle(.plain)
                .lineLimit(isNoteEditing ? 1...10 : 1...WPContentSheetStyle.noteMaxLines)
                .focused($focusedField, equals: .note)
        }
        .padding(WPSpacing.sm)
        .background(Color.wpSurface)
        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
        .overlay {
            if isNoteEditing {
                RoundedRectangle(cornerRadius: WPCornerRadius.medium)
                    .strokeBorder(Color.wpPrimary, lineWidth: 1)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.wpBorder.opacity(0.3)).frame(height: 0.5)

            HStack(spacing: WPSpacing.sm) {
                // Delete button (small, left side)
                Button {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.wpCallout)
                        .foregroundStyle(Color.wpTextTertiary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Promote button (inbox only, when ready)
                if viewModel.canPromote {
                    Button {
                        viewModel.promote()
                        onDismiss()
                    } label: {
                        HStack(spacing: WPSpacing.xxs) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.wpCaption)
                            Text("Promote")
                                .font(.wpSubheadline)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(Color.wpOnPrimary)
                        .padding(.horizontal, WPSpacing.md)
                        .padding(.vertical, WPSpacing.xs)
                        .background(Color.wpPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                    }
                    .buttonStyle(.plain)
                }

                // Save button
                Button {
                    viewModel.save()
                    onDismiss()
                } label: {
                    Text("Save")
                        .font(.wpSubheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.wpOnPrimary)
                        .padding(.horizontal, WPSpacing.lg)
                        .padding(.vertical, WPSpacing.xs)
                        .background(Color.wpPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, WPSpacing.md)
            .padding(.vertical, WPSpacing.sm)
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
                                .font(.wpCallout)
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
                                    .font(.wpCallout)
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
                                            .font(.wpCallout)
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
}
