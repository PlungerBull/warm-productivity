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
            .padding(.top, WPSpacing.sm)
            .padding(.bottom, WPSpacing.xs)
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

    // MARK: - Date Pill (icon-only)

    private var datePill: some View {
        Button { showDatePicker = true } label: {
            Image(systemName: "calendar")
                .wpIconPill(state: viewModel.resolvedDate != nil
                    ? .filled(color: Color.wpSuccess)
                    : .empty)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Pill (icon-only)

    private var categoryPill: some View {
        Menu {
            ForEach(viewModel.categories, id: \.id) { category in
                Button(category.name) {
                    viewModel.overrideCategoryId = category.id
                }
            }
        } label: {
            Image(systemName: "tag")
                .wpIconPill(state: resolvedCategoryId != nil
                    ? .filled(color: Color.wpPrimary)
                    : .empty)
        }
    }

    private var resolvedCategoryId: UUID? {
        viewModel.resolvedCategoryId
    }

    // MARK: - Account Pill (icon-only)

    private var accountPill: some View {
        Menu {
            ForEach(viewModel.accounts, id: \.id) { account in
                Button(account.name) {
                    viewModel.overrideAccountId = account.id
                }
            }
        } label: {
            Image(systemName: "building.columns")
                .wpIconPill(state: viewModel.resolvedAccountId != nil
                    ? .filled(color: Color.wpSuccess)
                    : .empty)
        }
    }

    // MARK: - Hashtag Pill (icon-only)

    private var hashtagPills: some View {
        Image(systemName: "number")
            .wpIconPill(state: viewModel.parsedHashtags.isEmpty
                ? .empty
                : .filled(color: Color.wpHashtag))
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
