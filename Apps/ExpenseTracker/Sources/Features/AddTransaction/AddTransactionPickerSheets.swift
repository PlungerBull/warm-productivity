import SwiftUI
import SharedUI
import SharedModels

// MARK: - Date Picker Sheet

struct AddTransactionDatePicker: View {
    @Binding var date: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            DatePicker(
                "Date",
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Category Picker Sheet

struct AddTransactionCategoryPicker: View {
    @Bindable var viewModel: AddTransactionViewModel
    @Binding var isPresented: Bool
    @State private var searchText: String = ""

    private var filteredCategories: [ExpenseCategory] {
        guard !searchText.isEmpty else { return viewModel.categories }
        let query = searchText.lowercased()
        return viewModel.categories.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: WPSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.wpTextTertiary)
                    TextField("Search or create...", text: $searchText)
                        .font(.wpBody)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, WPSpacing.sm)
                .padding(.vertical, WPSpacing.xs)
                .background(Color.wpGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                .padding(.horizontal, WPSpacing.md)
                .padding(.top, WPSpacing.sm)
                .padding(.bottom, WPSpacing.xs)

                List {
                    // Create new option
                    if !searchText.isEmpty && !viewModel.categories.contains(where: {
                        $0.name.caseInsensitiveCompare(searchText) == .orderedSame
                    }) {
                        Button {
                            viewModel.createCategory(name: searchText)
                            searchText = ""
                            isPresented = false
                        } label: {
                            HStack(spacing: WPSpacing.xs) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.wpPrimary)
                                Text("Create \"\(searchText)\"")
                                    .font(.wpBody)
                                    .foregroundStyle(Color.wpPrimary)
                            }
                        }
                    }

                    ForEach(filteredCategories, id: \.id) { category in
                        Button {
                            viewModel.selectedCategoryId = category.id
                            isPresented = false
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
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.selectedCategoryId != nil {
                        Button {
                            viewModel.selectedCategoryId = nil
                            isPresented = false
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
}

// MARK: - Account Picker Sheet

struct AddTransactionAccountPicker: View {
    @Bindable var viewModel: AddTransactionViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List(viewModel.accounts, id: \.id) { account in
                Button {
                    viewModel.selectedAccountId = account.id
                    viewModel.autoPopulateExchangeRate()
                    isPresented = false
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
                    Button("Done") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Hashtag Picker Sheet

struct AddTransactionHashtagPicker: View {
    @Bindable var viewModel: AddTransactionViewModel
    @Binding var isPresented: Bool
    @State private var searchText: String = ""

    private var selectedHashtags: [ExpenseHashtag] {
        viewModel.hashtags.filter { viewModel.selectedHashtagIds.contains($0.id) }
    }

    private var unselectedHashtags: [ExpenseHashtag] {
        let filtered = viewModel.hashtags.filter { !viewModel.selectedHashtagIds.contains($0.id) }
        guard !searchText.isEmpty else { return filtered }
        let query = searchText.lowercased()
        return filtered.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: WPSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.wpTextTertiary)
                    TextField("Search or create...", text: $searchText)
                        .font(.wpBody)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, WPSpacing.sm)
                .padding(.vertical, WPSpacing.xs)
                .background(Color.wpGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                .padding(.horizontal, WPSpacing.md)
                .padding(.top, WPSpacing.sm)
                .padding(.bottom, WPSpacing.xs)

                List {
                    // Create new option
                    if !searchText.isEmpty && !viewModel.hashtags.contains(where: {
                        $0.name.caseInsensitiveCompare(searchText) == .orderedSame
                    }) {
                        Button {
                            viewModel.createHashtag(name: searchText)
                            searchText = ""
                        } label: {
                            HStack(spacing: WPSpacing.xs) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.wpHashtag)
                                Text("Create \"#\(searchText)\"")
                                    .font(.wpBody)
                                    .foregroundStyle(Color.wpHashtag)
                            }
                        }
                    }

                    if !selectedHashtags.isEmpty {
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
                        ForEach(unselectedHashtags, id: \.id) { hashtag in
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
                    Button("Done") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
