import SwiftUI
import SharedUI
import SharedModels
import SharedUtilities

struct QuickEntryView: View {
    @State private var viewModel: QuickEntryViewModel
    let onDismiss: () -> Void

    @State private var showDatePicker: Bool = false

    init(viewModel: QuickEntryViewModel, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: WPSpacing.md) {
                // Command input
                VStack(alignment: .leading, spacing: WPSpacing.xs) {
                    TextField(
                        "-45 Lunch @Food $BCP #work today",
                        text: $viewModel.commandText
                    )
                    .font(.wpBody)
                    .padding(WPSpacing.sm)
                    .background(Color.wpSurface)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: WPCornerRadius.small)
                            .stroke(Color.wpBorder, lineWidth: 1)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: viewModel.commandText) {
                        viewModel.parseCommand()
                    }

                    // Parsed tokens preview
                    if viewModel.parsedTitle != nil || viewModel.parsedAmountCents != nil {
                        parsedPreview
                    }
                }

                // Description
                TextField("Add a note...", text: $viewModel.descriptionText, axis: .vertical)
                    .font(.wpBody)
                    .lineLimit(2...4)
                    .padding(WPSpacing.sm)
                    .background(Color.wpSurface)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: WPCornerRadius.small)
                            .stroke(Color.wpBorder, lineWidth: 1)
                    )

                // Quick-set toolbar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WPSpacing.xs) {
                        // Date — single select: Today / Yesterday / Pick date
                        selectableChip(
                            "Today",
                            icon: "calendar",
                            isSelected: isDateToday
                        ) {
                            viewModel.overrideDate = Calendar.current.startOfDay(for: Date())
                        }

                        selectableChip(
                            "Yesterday",
                            icon: "calendar.badge.minus",
                            isSelected: isDateYesterday
                        ) {
                            viewModel.overrideDate = Calendar.current.date(
                                byAdding: .day, value: -1,
                                to: Calendar.current.startOfDay(for: Date())
                            )
                        }

                        selectableChip(
                            datePickerLabel,
                            icon: "calendar.badge.clock",
                            isSelected: isDateCustom
                        ) {
                            showDatePicker = true
                        }

                        Divider().frame(height: 24)

                        // Account picker
                        Menu {
                            ForEach(viewModel.accounts, id: \.id) { account in
                                Button(account.name) {
                                    viewModel.overrideAccountId = account.id
                                }
                            }
                        } label: {
                            let name = viewModel.resolvedAccountId.flatMap { id in
                                viewModel.accounts.first { $0.id == id }?.name
                            }
                            chipLabel(
                                name ?? "Account",
                                icon: "building.columns",
                                isSelected: name != nil
                            )
                        }

                        // Category picker
                        Menu {
                            ForEach(viewModel.categories, id: \.id) { category in
                                Button(category.name) {
                                    viewModel.overrideCategoryId = category.id
                                }
                            }
                        } label: {
                            let name = viewModel.resolvedCategoryId.flatMap { id in
                                viewModel.categories.first { $0.id == id }?.name
                            }
                            chipLabel(
                                name ?? "Category",
                                icon: "folder",
                                isSelected: name != nil
                            )
                        }
                    }
                    .padding(.horizontal, WPSpacing.xxs)
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                Spacer()

                // Submit button
                Button {
                    viewModel.submit()
                    if viewModel.errorMessage == nil {
                        onDismiss()
                    }
                } label: {
                    Text(viewModel.submitLabel)
                        .font(.wpHeadline)
                        .foregroundStyle(Color.wpOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(
                    viewModel.commandText.isEmpty ? Color.wpTextTertiary : Color.wpPrimary
                )
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                .disabled(viewModel.commandText.isEmpty || viewModel.isSubmitting)
            }
            .padding(WPSpacing.md)
            .background(Color.wpBackground)
            .navigationTitle("Quick Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .task {
                viewModel.loadPickerData()
            }
        }
    }

    // MARK: - Date Helpers

    private var isDateToday: Bool {
        guard let d = viewModel.resolvedDate else { return false }
        return Calendar.current.isDateInToday(d)
    }

    private var isDateYesterday: Bool {
        guard let d = viewModel.resolvedDate else { return false }
        return Calendar.current.isDateInYesterday(d)
    }

    private var isDateCustom: Bool {
        guard let d = viewModel.resolvedDate else { return false }
        return !Calendar.current.isDateInToday(d) && !Calendar.current.isDateInYesterday(d)
    }

    private var datePickerLabel: String {
        if isDateCustom, let d = viewModel.resolvedDate {
            return CurrencyFormatter.formatDate(d)
        }
        return "Pick date"
    }

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

    // MARK: - Parsed Preview

    private var parsedPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WPSpacing.xs) {
                if let amount = viewModel.parsedAmountCents {
                    Text(amount < 0 ? "Expense" : "Income")
                        .font(.wpCaption)
                        .foregroundStyle(amount < 0 ? Color.wpExpense : Color.wpIncome)
                        .padding(.horizontal, WPSpacing.xs)
                        .padding(.vertical, 2)
                        .background((amount < 0 ? Color.wpExpense : Color.wpIncome).opacity(0.1))
                        .clipShape(Capsule())

                    Text(String(format: "%.2f", Double(abs(amount)) / 100.0))
                        .font(.wpCaption.monospacedDigit())
                        .foregroundStyle(Color.wpTextSecondary)
                }
                if let title = viewModel.parsedTitle {
                    Text(title)
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextSecondary)
                        .lineLimit(1)
                }
                if let category = viewModel.parsedCategoryName {
                    Text("@\(category)")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpPrimary)
                }
                if let account = viewModel.parsedAccountName {
                    Text("$\(account)")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpSecondary)
                }
                ForEach(viewModel.parsedHashtags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextSecondary)
                }
            }
        }
    }

    // MARK: - Chip Helpers

    private func selectableChip(
        _ label: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            chipLabel(label, icon: icon, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func chipLabel(_ label: String, icon: String, isSelected: Bool = false) -> some View {
        HStack(spacing: WPSpacing.xxs) {
            Image(systemName: icon)
                .font(.wpCaption)
            Text(label)
                .font(.wpCaption)
        }
        .padding(.horizontal, WPSpacing.sm)
        .padding(.vertical, WPSpacing.xs)
        .background(isSelected ? Color.wpPrimary.opacity(0.1) : Color.wpSurface)
        .foregroundStyle(isSelected ? Color.wpPrimary : Color.wpTextPrimary)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(isSelected ? Color.wpPrimary : Color.wpBorder, lineWidth: 1)
        )
    }
}
