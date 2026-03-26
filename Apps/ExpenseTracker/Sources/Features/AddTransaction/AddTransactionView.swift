import SwiftUI
import SharedUI
import SharedModels
import SharedUtilities

struct AddTransactionView: View {
    @State var viewModel: AddTransactionViewModel
    let onDismiss: () -> Void

    @State private var showDatePicker = false
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showHashtagPicker = false

    @FocusState private var focusedField: InputField?

    enum InputField: Hashable {
        case title
        case description
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            headerRow
            amountHero
            if viewModel.showExchangeRate {
                exchangeRateSubtitle
            }
            titleField
            metadataPills
            inputZone
            saveButton
        }
        .background(Color.wpBackground)
        .overlay { confirmationOverlay }
        .sheet(isPresented: $showDatePicker) {
            AddTransactionDatePicker(date: $viewModel.date, isPresented: $showDatePicker)
        }
        .sheet(isPresented: $showCategoryPicker) {
            AddTransactionCategoryPicker(viewModel: viewModel, isPresented: $showCategoryPicker)
        }
        .sheet(isPresented: $showAccountPicker) {
            AddTransactionAccountPicker(viewModel: viewModel, isPresented: $showAccountPicker)
        }
        .sheet(isPresented: $showHashtagPicker) {
            AddTransactionHashtagPicker(viewModel: viewModel, isPresented: $showHashtagPicker)
        }
        .task {
            viewModel.loadPickerData()
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: WPContentSheetStyle.handleCornerRadius)
            .fill(Color.wpTextTertiary.opacity(0.4))
            .frame(width: WPContentSheetStyle.handleWidth, height: WPContentSheetStyle.handleHeight + 1)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.wpTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.wpGroupedBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            typeToggle

            Spacer()

            // Balance the close button width
            Color.clear.frame(width: 30, height: 30)
        }
        .padding(.horizontal, WPSpacing.md)
        .padding(.bottom, WPSpacing.xxs)
    }

    private var typeToggle: some View {
        HStack(spacing: 0) {
            segmentButton("Expense", isSelected: viewModel.isExpense) {
                viewModel.isExpense = true
            }
            segmentButton("Income", isSelected: !viewModel.isExpense) {
                viewModel.isExpense = false
            }
        }
        .padding(3)
        .background(Color.wpGroupedBackground)
        .clipShape(Capsule())
    }

    private func segmentButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.wpTextPrimary : Color.wpTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(isSelected ? Color.wpBackground : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isSelected ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount Hero

    private var amountHero: some View {
        VStack(spacing: 4) {
            // Sign + currency code
            Text(amountMetaText)
                .font(.wpHeroCurrencyCode)
                .foregroundStyle(amountMetaColor)

            // Amount display
            HStack(spacing: 0) {
                Text(viewModel.formattedAmount)
                    .font(.wpHeroAmount)
                    .foregroundStyle(amountValueColor)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.15), value: viewModel.formattedAmount)

                // Blinking cursor when numpad is active
                if focusedField == nil {
                    Rectangle()
                        .fill(Color.wpPrimary)
                        .frame(width: 2, height: 36)
                        .opacity(cursorOpacity)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: cursorOpacity)
                        .onAppear { cursorVisible = true }
                }
            }
        }
        .padding(.top, WPSpacing.md)
        .padding(.bottom, WPSpacing.xs)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }

    @State private var cursorVisible = false
    private var cursorOpacity: Double { cursorVisible ? 1 : 0 }

    private var amountMetaText: String {
        let sign = viewModel.isExpense ? "\u{2212}" : "+"
        if viewModel.amountString.isEmpty {
            return viewModel.accountCurrency
        }
        return "\(sign) \(viewModel.accountCurrency)"
    }

    private var amountMetaColor: Color {
        if viewModel.amountString.isEmpty { return Color.wpTextTertiary }
        return viewModel.isExpense ? Color.wpTextSecondary : Color.wpIncome
    }

    private var amountValueColor: Color {
        if viewModel.amountString.isEmpty { return Color.wpTextTertiary }
        return viewModel.isExpense ? Color.wpTextPrimary : Color.wpIncome
    }

    // MARK: - Exchange Rate Subtitle

    private var exchangeRateSubtitle: some View {
        Group {
            if let cents = viewModel.amountCents,
               let rate = Decimal(string: viewModel.exchangeRate) {
                let homeCents = NSDecimalNumber(decimal: Decimal(cents) * rate).int64Value
                let formatter = CurrencyFormatter(currencyCode: viewModel.mainCurrency)
                Text("\u{2248} \(formatter.formatSigned(homeCents)) \u{00B7} 1 \(viewModel.mainCurrency) = \(viewModel.exchangeRate) \(viewModel.accountCurrency)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.wpTextSecondary)
            }
        }
        .padding(.top, WPSpacing.xxs)
    }

    // MARK: - Title Field

    private var titleField: some View {
        TextField("What was this for?", text: $viewModel.title)
            .font(.system(size: 16))
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .title)
            .padding(.horizontal, WPSpacing.xl)
            .padding(.top, WPSpacing.sm)
            .padding(.bottom, WPSpacing.xs)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(titleUnderlineColor)
                    .frame(height: 1.5)
                    .padding(.horizontal, WPSpacing.xl)
            }
    }

    private var titleUnderlineColor: Color {
        if focusedField == .title || !viewModel.title.isEmpty {
            return Color.wpPrimary
        }
        return Color.wpBorder
    }

    // MARK: - Metadata Pills

    private var metadataPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WPSpacing.xs) {
                datePill
                categoryPill
                accountPill
                notePill
                hashtagPill
            }
            .padding(.horizontal, WPSpacing.md)
        }
        .scrollIndicators(.hidden)
        .padding(.top, WPSpacing.sm)
    }

    private var datePill: some View {
        Button { showDatePicker = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text(formattedDate)
            }
            .wpMetadataPill(state: .filled)
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(viewModel.date) { return "Today" }
        if calendar.isDateInYesterday(viewModel.date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: viewModel.date)
    }

    private var categoryPill: some View {
        Button { showCategoryPicker = true } label: {
            if let category = viewModel.selectedCategory {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: category.color))
                        .frame(width: 7, height: 7)
                    Text(category.name)
                }
                .wpMetadataPill(state: .filled)
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "tag")
                        .font(.system(size: 11))
                    Text("Category")
                }
                .wpMetadataPill(state: .empty)
            }
        }
        .buttonStyle(.plain)
    }

    private var accountPill: some View {
        Button { showAccountPicker = true } label: {
            if let account = viewModel.selectedAccount {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: account.color))
                        .frame(width: 7, height: 7)
                    Text(account.name)
                }
                .wpMetadataPill(state: .filled)
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 11))
                    Text("Account")
                }
                .wpMetadataPill(state: .empty)
            }
        }
        .buttonStyle(.plain)
    }

    private var notePill: some View {
        Button {
            if focusedField == .description {
                focusedField = nil
            } else {
                focusedField = .description
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                Text(viewModel.hasDescription ? "Added" : "Note")
            }
            .wpMetadataPill(state: focusedField == .description ? .active
                : viewModel.hasDescription ? .filled : .empty)
        }
        .buttonStyle(.plain)
    }

    private var hashtagPill: some View {
        Button { showHashtagPicker = true } label: {
            if viewModel.selectedHashtagIds.isEmpty {
                HStack(spacing: 5) {
                    Text("#")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Tag")
                }
                .wpMetadataPill(state: .empty)
            } else {
                HStack(spacing: 5) {
                    Text("#")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(viewModel.selectedHashtagIds.count)")
                }
                .wpMetadataPill(state: .filled)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Zone (numpad / keyboard / description)

    @ViewBuilder
    private var inputZone: some View {
        switch focusedField {
        case nil:
            // Numpad mode (default)
            NumpadView { key in
                viewModel.handleNumpadKey(key)
            }
            .padding(.horizontal, WPSpacing.md)
            .padding(.top, WPSpacing.sm)

        case .title:
            // System keyboard handles this — just show empty space
            Spacer()
                .frame(minHeight: WPSpacing.md)

        case .description:
            // Description card
            descriptionCard
        }
    }

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: WPSpacing.xxs) {
            Text("DESCRIPTION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.wpPrimary)

            TextField("Add a note...", text: $viewModel.descriptionText, axis: .vertical)
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextPrimary)
                .textFieldStyle(.plain)
                .lineLimit(2...8)
                .focused($focusedField, equals: .description)
        }
        .padding(14)
        .background(Color.wpSurface)
        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: WPCornerRadius.medium)
                .strokeBorder(Color.wpPrimary, lineWidth: 1.5)
        }
        .padding(.horizontal, WPSpacing.md)
        .padding(.top, WPSpacing.sm)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            viewModel.submit()
        } label: {
            Group {
                switch viewModel.saveButtonState {
                case .disabled:
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.wpGroupedBackground)
                        .foregroundStyle(Color.wpTextTertiary)

                case .draft:
                    HStack(spacing: WPSpacing.xxs) {
                        Text("Save as Draft")
                        Text("\u{2192} Inbox")
                            .font(.system(size: 12))
                            .opacity(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.wpPrimary, lineWidth: 1.5)
                    }
                    .foregroundStyle(Color.wpPrimary)

                case .ledger:
                    HStack(spacing: WPSpacing.xxs) {
                        Text("Save to Ledger")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14))
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.isExpense ? Color.wpPrimary : Color.wpIncome)
                    .foregroundStyle(Color.wpOnPrimary)
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.saveButtonState == .disabled || viewModel.isSubmitting)
        .padding(.horizontal, WPSpacing.md)
        .padding(.top, WPSpacing.sm)
        .padding(.bottom, WPSpacing.lg)
        .animation(.easeInOut(duration: 0.2), value: viewModel.saveButtonState)
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        Group {
            if viewModel.showSaveConfirmation {
                ZStack {
                    Color.wpBackground.opacity(0.8)
                    VStack(spacing: WPSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.wpIncome)
                        Text("Saved")
                            .font(.wpHeadline)
                            .foregroundStyle(Color.wpTextPrimary)
                    }
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewModel.resetForNextEntry()
                        }
                    }
                }
            }
        }
        .animation(.easeIn(duration: 0.15), value: viewModel.showSaveConfirmation)
    }
}
