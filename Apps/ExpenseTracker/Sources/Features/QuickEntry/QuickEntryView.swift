import SwiftUI
import SharedUI
import SharedModels
import SharedUtilities

struct QuickEntryView: View {
    @State private var viewModel: QuickEntryViewModel
    let onDismiss: () -> Void
    @Binding var sheetHeight: CGFloat

    @State private var showDatePicker: Bool = false
    @State private var showCategoryPicker: Bool = false
    @State private var showAccountPicker: Bool = false
    @FocusState private var isCommandFocused: Bool

    private static let maxSheetHeight: CGFloat = 350

    init(viewModel: QuickEntryViewModel, onDismiss: @escaping () -> Void, sheetHeight: Binding<CGFloat>) {
        _viewModel = State(initialValue: viewModel)
        self.onDismiss = onDismiss
        _sheetHeight = sheetHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Destination badge — subtle indicator of where this entry will land
            destinationBadge
                .padding(.horizontal, WPSpacing.md)
                .padding(.top, WPSpacing.sm)
                .padding(.bottom, WPSpacing.xxs)

            // Command input — large, prominent, the hero element
            TextField(
                "e.g. -45 Lunch @Food $BCP",
                text: $viewModel.commandText
            )
            .font(.wpHeadline)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isCommandFocused)
            .padding(.horizontal, WPSpacing.md)
            .padding(.vertical, WPSpacing.xs)
            .onChange(of: viewModel.commandText) {
                viewModel.parseCommand()
            }

            // Description field — Notion-style minimal text input
            TextField("Add a note...", text: $viewModel.descriptionText, axis: .vertical)
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextSecondary)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .padding(.horizontal, WPSpacing.md)
                .padding(.top, WPSpacing.xxs)

            // Error banner
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
                .padding(.horizontal, WPSpacing.md)
                .padding(.top, WPSpacing.xs)
            }

            // Toolbar row — pills + send
            toolbarRow
                .padding(.horizontal, WPSpacing.sm)
                .padding(.top, WPSpacing.sm)
                .padding(.bottom, WPSpacing.xs)
        }
        .ignoresSafeArea(.keyboard)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            sheetHeight = min(newHeight, Self.maxSheetHeight)
        }
        .onAppear {
            isCommandFocused = true
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
        .task {
            viewModel.loadPickerData()
        }
    }

    // MARK: - Destination Badge

    private var destinationBadge: some View {
        HStack(spacing: WPSpacing.xxs) {
            Image(systemName: viewModel.canGoToLedger ? "checkmark.circle.fill" : "tray.fill")
                .font(.wpCaption2)
            Text(viewModel.canGoToLedger ? "Ledger" : "Inbox")
                .font(.wpCaption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(viewModel.canGoToLedger ? Color.wpSuccess : Color.wpTextTertiary)
        .animation(.easeInOut(duration: 0.2), value: viewModel.canGoToLedger)
    }

    // MARK: - Toolbar Row

    private var toolbarRow: some View {
        HStack(spacing: WPSpacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WPSpacing.xs) {
                    amountPill
                    datePill
                    categoryPill
                    accountPill
                    hashtagPills
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .scrollClipDisabled()

            Spacer(minLength: WPSpacing.xs)

            sendButton
        }
    }

    // MARK: - Amount Pill

    private var amountPill: some View {
        let hasAmount = viewModel.parsedAmountCents != nil
        let amountColor: Color = if let cents = viewModel.parsedAmountCents {
            cents < 0 ? Color.wpTextPrimary : Color.wpIncome
        } else {
            Color.wpTextTertiary
        }
        return HStack(spacing: WPSpacing.xxs) {
            if let cents = viewModel.parsedAmountCents {
                Text(CurrencyFormatter(currencyCode: viewModel.mainCurrency).formatSigned(cents))
            } else {
                Text("Amount")
            }
        }
        .wpToolbarPill(
            state: hasAmount ? .selected : .unselected,
            color: amountColor
        )
    }

    // MARK: - Hashtag Pills

    @ViewBuilder
    private var hashtagPills: some View {
        if viewModel.parsedHashtags.isEmpty {
            HStack(spacing: WPSpacing.xxs) {
                Image(systemName: "number")
            }
            .wpToolbarPill(state: .unselected, color: Color.wpHashtag)
        } else {
            ForEach(viewModel.parsedHashtags, id: \.self) { tag in
                HStack(spacing: WPSpacing.xxs) {
                    Image(systemName: "number")
                    Text(tag)
                }
                .wpToolbarPill(state: .selected, color: Color.wpHashtag)
            }
        }
    }

    // MARK: - Date Pill

    private var datePill: some View {
        Button { showDatePicker = true } label: {
            let hasDate = viewModel.resolvedDate != nil
            HStack(spacing: WPSpacing.xxs) {
                Image(systemName: "calendar")
                if hasDate {
                    Text(dateDisplayText)
                }
            }
            .wpToolbarPill(
                state: hasDate ? .selected : .unselected,
                color: Color.wpSuccess
            )
        }
        .buttonStyle(.plain)
    }

    private var dateDisplayText: String {
        guard let date = viewModel.resolvedDate else { return "" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return CurrencyFormatter.formatDate(date)
    }

    // MARK: - Category Pill

    private var categoryPill: some View {
        Menu {
            ForEach(viewModel.categories, id: \.id) { category in
                Button(category.name) {
                    viewModel.overrideCategoryId = category.id
                }
            }
        } label: {
            let name = resolvedCategoryName
            let hasCategory = name != nil
            HStack(spacing: WPSpacing.xxs) {
                Image(systemName: "tag")
                if let name {
                    Text(name)
                }
            }
            .wpToolbarPill(
                state: hasCategory ? .selected : .missing,
                color: Color.wpPrimary
            )
        }
    }

    private var resolvedCategoryName: String? {
        viewModel.resolvedCategoryId.flatMap { id in
            viewModel.categories.first { $0.id == id }?.name
        }
    }

    // MARK: - Account Pill

    private var accountPill: some View {
        Menu {
            ForEach(viewModel.accounts, id: \.id) { account in
                Button(account.name) {
                    viewModel.overrideAccountId = account.id
                }
            }
        } label: {
            let name = resolvedAccountName
            let hasAccount = name != nil
            HStack(spacing: WPSpacing.xxs) {
                Image(systemName: "building.columns")
                if let name {
                    Text(name)
                }
            }
            .wpToolbarPill(
                state: hasAccount ? .selected : .missing,
                color: Color.wpSuccess
            )
        }
    }

    private var resolvedAccountName: String? {
        viewModel.resolvedAccountId.flatMap { id in
            viewModel.accounts.first { $0.id == id }?.name
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            viewModel.submit()
            if viewModel.errorMessage == nil {
                onDismiss()
            }
        } label: {
            let isReady = !viewModel.commandText.isEmpty
            ZStack {
                Circle()
                    .fill(isReady ? Color.wpPrimary : Color.wpTextTertiary.opacity(0.3))
                    .frame(width: WPSendButtonStyle.size, height: WPSendButtonStyle.size)

                Image(systemName: "arrow.up")
                    .font(.system(size: WPSendButtonStyle.iconSize, weight: .semibold))
                    .foregroundStyle(Color.wpOnPrimary)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.commandText.isEmpty || viewModel.isSubmitting)
        .animation(.easeInOut(duration: 0.15), value: viewModel.commandText.isEmpty)
    }

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: Binding(
                    get: { viewModel.overrideDate ?? Date() },
                    set: { viewModel.overrideDate = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
