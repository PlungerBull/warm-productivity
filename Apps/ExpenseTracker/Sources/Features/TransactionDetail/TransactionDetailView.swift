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
    @State private var selectedDetent: PresentationDetent = .fraction(0.75)

    private var isCompact: Bool {
        focusedField != nil
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
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
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
        .presentationDetents([.fraction(0.75), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationSizing(.page)
        .onChange(of: focusedField) { _, newValue in
            withAnimation {
                selectedDetent = newValue != nil ? .large : .fraction(0.75)
            }
        }
        .task {
            viewModel.load(mode: mode)
        }
    }

    // MARK: - Sheet Content

    private var sheetContent: some View {
        VStack(spacing: 0) {
            heroSection
            pillsSection
            ScrollView {
                VStack(spacing: WPSpacing.sm) {
                    metadataRows
                    noteCard
                }
                .padding(.horizontal, WPSpacing.md)
                .padding(.vertical, WPSpacing.sm)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        let amountFont = isCompact ? Font.wpCompactAmount : Font.wpHeroAmount
        let titleFont = isCompact ? Font.wpCompactTitle : Font.wpHeroTitle
        let currencyFont = isCompact ? Font.wpCompactCurrencyCode : Font.wpHeroCurrencyCode

        return VStack(spacing: WPSpacing.xs) {
            // Title
            TextField("Untitled transaction", text: $viewModel.title)
                .font(titleFont)
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

            // Amount — centered: sign + currency code + number
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                // Sign toggle
                Button {
                    viewModel.isExpense.toggle()
                } label: {
                    Text(viewModel.isExpense ? "\u{2212}" : "+")
                        .font(amountFont)
                        .foregroundStyle(amountColor)
                }
                .buttonStyle(.plain)
                .contentTransition(.numericText())

                // Currency code — same line, after sign
                if let currency = viewModel.accountCurrency {
                    Text(currency)
                        .font(currencyFont)
                        .foregroundStyle(Color.wpTextTertiary)
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                        .padding(.trailing, WPSpacing.xxs)
                }

                // Amount field
                TextField("0.00", text: $viewModel.amountString)
                    .font(amountFont)
                    .foregroundStyle(amountColor)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 0)
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
        .padding(.top, WPSpacing.lg)
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
                        .font(.wpPillLabel)
                }
                .wpToolbarPill(state: .selected, color: Color.wpTextSecondary)
            }
            .buttonStyle(.plain)

            // Category pill
            Button { showCategoryPicker = true } label: {
                if let category = selectedCategory {
                    HStack(spacing: WPSpacing.xxs) {
                        Circle().fill(Color(hex: category.color)).frame(width: 7, height: 7)
                        Text(category.name).font(.wpPillLabel)
                    }
                    .wpToolbarPill(state: .selected, color: Color(hex: category.color))
                } else {
                    HStack(spacing: WPSpacing.xxs) {
                        Image(systemName: "tag").font(.wpCaption)
                        Text("Category").font(.wpPillLabel)
                    }
                    .wpToolbarPill(state: .unselected, color: Color.wpTextTertiary)
                }
            }
            .buttonStyle(.plain)

            // Account pill
            Button { showAccountPicker = true } label: {
                HStack(spacing: WPSpacing.xxs) {
                    Image(systemName: "building.columns").font(.wpCaption)
                    Text(selectedAccountName).font(.wpPillLabel)
                }
                .wpToolbarPill(
                    state: viewModel.selectedAccountId != nil ? .selected : .unselected,
                    color: viewModel.selectedAccountId != nil ? Color.wpSuccess : Color.wpTextTertiary
                )
            }
            .buttonStyle(.plain)

            // Hashtag pills — one per hashtag
            ForEach(selectedHashtags, id: \.id) { hashtag in
                Button { showHashtagPicker = true } label: {
                    Text("#\(hashtag.name)")
                        .font(.wpPillLabel)
                        .wpToolbarPill(state: .selected, color: Color.wpHashtag)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Metadata Rows

    private var metadataRows: some View {
        VStack(spacing: 0) {
            // Income/Expense row
            metadataRow(
                icon: viewModel.isExpense ? "arrow.down" : "arrow.up",
                iconColor: viewModel.isExpense ? Color.wpTextSecondary : Color.wpIncome,
                label: viewModel.isExpense ? "Expense" : "Income",
                showDivider: viewModel.showExchangeRate
            ) {
                Text(formattedTransactionAmount)
                    .font(.wpCallout)
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.isExpense ? Color.wpExpense : Color.wpIncome)
            }

            if viewModel.showExchangeRate {
                // Exchange rate row
                metadataRow(
                    icon: "arrow.left.arrow.right",
                    iconColor: Color.wpTextSecondary,
                    label: "Exchange rate",
                    showDivider: true
                ) {
                    HStack(spacing: WPSpacing.xxs) {
                        Text("\(viewModel.accountCurrency ?? "") \u{2192} \(viewModel.currencyFormatter.currencyCode) \u{00D7}")
                            .font(.wpCallout)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.wpTextPrimary)
                        TextField("1.0", text: $viewModel.exchangeRate)
                            .font(.wpCallout)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.wpTextSecondary)
                            .textFieldStyle(.plain)
                            .keyboardType(.decimalPad)
                            .frame(width: 50)
                    }
                }

                // Home amount row
                metadataRow(
                    icon: "house",
                    iconColor: Color.wpTextSecondary,
                    label: "Home amount",
                    showDivider: false
                ) {
                    Text(formattedHomeAmount)
                        .font(.wpCallout)
                        .fontWeight(.medium)
                        .foregroundStyle(viewModel.isExpense ? Color.wpExpense : Color.wpIncome)
                }
            }
        }
        .padding(.horizontal, WPSpacing.md)
    }

    private func metadataRow<V: View>(
        icon: String,
        iconColor: Color,
        label: String,
        showDivider: Bool,
        @ViewBuilder value: () -> V
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: WPSpacing.sm) {
                // Icon box
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))

                // Label
                Text(label)
                    .font(.wpCallout)
                    .foregroundStyle(Color.wpTextSecondary)

                Spacer()

                // Value
                value()
            }
            .padding(.vertical, 14)

            if showDivider {
                Rectangle()
                    .fill(Color.wpBorder.opacity(0.25))
                    .frame(height: 0.5)
            }
        }
    }

    private var formattedTransactionAmount: String {
        guard let amountCents = viewModel.parsedAmountCents else { return "\u{2014}" }
        let sign = viewModel.isExpense ? "\u{2212}" : "+"
        let currency = viewModel.accountCurrency ?? viewModel.currencyFormatter.currencyCode
        let amount = abs(amountCents)
        let whole = amount / 100
        let frac = amount % 100
        return "\(sign)\(currency) \(whole).\(String(format: "%02d", frac))"
    }

    private var formattedHomeAmount: String {
        guard let amountCents = viewModel.parsedAmountCents,
              let rateValue = Double(viewModel.exchangeRate),
              rateValue > 0 else {
            return "\u{2014}"
        }
        let homeCents = Double(abs(amountCents)) * rateValue / 100.0
        let sign = viewModel.isExpense ? "\u{2212}" : "+"
        return "\(sign)\(viewModel.currencyFormatter.currencyCode) \(String(format: "%.2f", homeCents))"
    }

    // MARK: - Note Card

    private var noteCard: some View {
        HStack(alignment: .top, spacing: WPSpacing.xs) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(isNoteEditing ? Color.wpPrimary : Color.wpTextTertiary)
                .padding(.top, 2)

            TextField("Add a note...", text: $viewModel.descriptionText, axis: .vertical)
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextPrimary)
                .textFieldStyle(.plain)
                .lineLimit(isNoteEditing ? 1...10 : 1...WPContentSheetStyle.noteMaxLines)
                .focused($focusedField, equals: .note)
        }
        .padding(14)
        .background(Color.wpSurface)
        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: WPCornerRadius.medium)
                .strokeBorder(
                    isNoteEditing ? Color.wpPrimary : Color.wpBorder.opacity(0.4),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: WPSpacing.sm) {
            // Delete button
            Button {
                viewModel.showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.wpTextTertiary)
                    .frame(width: 48, height: 48)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                    .overlay {
                        RoundedRectangle(cornerRadius: WPCornerRadius.medium)
                            .strokeBorder(Color.wpBorder, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.wpSuccess)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                }
                .buttonStyle(.plain)
            }

            // Save button — full width
            Button {
                viewModel.save()
                onDismiss()
            } label: {
                Text("Save")
                    .font(.wpSubheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.wpOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.wpPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WPSpacing.md)
        .padding(.vertical, WPSpacing.sm)
    }

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Date",
                selection: $viewModel.date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
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
