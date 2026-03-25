import SwiftUI
import SharedUI
import SharedModels
import SharedUtilities

struct QuickEntryView: View {
    @State private var viewModel: QuickEntryViewModel
    let onDismiss: () -> Void

    @State private var showDatePicker: Bool = false
    @State private var showCategoryPicker: Bool = false
    @State private var showAccountPicker: Bool = false
    @FocusState private var isCommandFocused: Bool

    init(viewModel: QuickEntryViewModel, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Command input
            TextField(
                "e.g. -45 Lunch @Food $BCP",
                text: $viewModel.commandText
            )
            .font(.wpBody)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isCommandFocused)
            .padding(.horizontal, WPSpacing.md)
            .padding(.vertical, WPSpacing.xs)
            .onChange(of: viewModel.commandText) {
                viewModel.parseCommand()
            }

            // Description field
            TextField("Description", text: $viewModel.descriptionText, axis: .vertical)
                .font(.wpCaption)
                .foregroundStyle(Color.wpTextTertiary)
                .textFieldStyle(.plain)
                .lineLimit(1...10)
                .padding(.horizontal, WPSpacing.md)
                .padding(.top, WPSpacing.xxs)

            // Error banner
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
                .padding(.horizontal, WPSpacing.md)
                .padding(.bottom, WPSpacing.xs)
            }

            // Toolbar row
            toolbarRow
                .padding(.horizontal, WPSpacing.sm)
                .padding(.top, WPSpacing.sm)
                .padding(.bottom, WPSpacing.xs)
        }
        .background(.clear)
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

    // MARK: - Destination Indicator

    // MARK: - Toolbar Row

    private var toolbarRow: some View {
        HStack(spacing: WPSpacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WPSpacing.xs) {
                    // Date pill
                    datePill

                    // Category pill
                    categoryPill

                    // Account pill
                    accountPill

                    // Overflow button
                    Button {
                        // Future: extra options
                    } label: {
                        Text("···")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.wpTextTertiary)
                            .frame(width: 32, height: 30)
                            .background(Color.wpSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: WPSpacing.xs)

            // Circular send button
            sendButton
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
                    .fill(isReady ? Color.wpPrimary : Color.wpTextTertiary.opacity(0.4))
                    .frame(width: WPSendButtonStyle.size, height: WPSendButtonStyle.size)

                Image(systemName: "arrow.up")
                    .font(.system(size: WPSendButtonStyle.iconSize, weight: .semibold))
                    .foregroundStyle(Color.wpOnPrimary)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.commandText.isEmpty || viewModel.isSubmitting)
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
