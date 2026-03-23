import SwiftUI
import SharedUI
import SharedModels
import SharedUtilities

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    let detailViewModelFactory: () -> TransactionDetailViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Bar + Cancel
            HStack(spacing: WPSpacing.sm) {
                HStack(spacing: WPSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.wpTextTertiary)
                        .font(.system(size: 15))

                    TextField("Search transactions...", text: $viewModel.query)
                        .font(.wpBody)
                        .foregroundStyle(Color.wpTextPrimary)
                        .focused($isSearchFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)

                    if !viewModel.query.isEmpty {
                        Button {
                            viewModel.query = ""
                            viewModel.search()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.wpTextTertiary)
                        }
                    }
                }
                .padding(.horizontal, WPSpacing.sm)
                .padding(.vertical, WPSpacing.xs)
                .background(Color.wpGroupedBackground)
                .clipShape(Capsule())

                Button("Cancel") {
                    dismiss()
                }
                .font(.wpBody)
                .foregroundStyle(Color.wpPrimary)
            }
            .padding(.horizontal, WPSpacing.md)
            .padding(.top, WPSpacing.md)
            .padding(.bottom, WPSpacing.sm)

            Divider()
                .overlay(Color.wpBorder)

            // MARK: - Content
            if viewModel.query.isEmpty {
                emptySearchState
            } else if viewModel.results.isEmpty && viewModel.inboxResults.isEmpty {
                noResultsState
            } else {
                resultsList
            }
        }
        .background(Color.wpBackground)
        .onChange(of: viewModel.query) {
            viewModel.search()
        }
        .sheet(isPresented: $viewModel.showDetail, onDismiss: {
            viewModel.search()
        }) {
            detailSheet
        }
        .task {
            viewModel.loadLookups()
            isSearchFocused = true
        }
    }

    // MARK: - Empty State (no query)

    private var emptySearchState: some View {
        VStack(spacing: WPSpacing.md) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.wpIconDecorative)
                .foregroundStyle(Color.wpTextTertiary)

            Text("Search Transactions")
                .font(.wpHeadline)
                .foregroundStyle(Color.wpTextPrimary)

            Text("Search by title, category, account, hashtag, amount, or notes.")
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, WPSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack(spacing: WPSpacing.md) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.wpIconDecorative)
                .foregroundStyle(Color.wpTextTertiary)

            Text("No Results")
                .font(.wpHeadline)
                .foregroundStyle(Color.wpTextPrimary)

            Text("Try a different search term or check your spelling.")
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, WPSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Ledger Section
                if !viewModel.results.isEmpty {
                    sectionHeader("LEDGER (\(viewModel.results.count) \(viewModel.results.count == 1 ? "RESULT" : "RESULTS"))")

                    ForEach(viewModel.results, id: \.id) { transaction in
                        ledgerRow(transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectLedgerItem(transaction)
                            }

                        Divider()
                            .overlay(Color.wpBorder)
                            .padding(.leading, WPSpacing.md)
                    }
                }

                // Inbox Section
                if !viewModel.inboxResults.isEmpty {
                    sectionHeader("INBOX (\(viewModel.inboxResults.count) \(viewModel.inboxResults.count == 1 ? "RESULT" : "RESULTS"))")

                    ForEach(viewModel.inboxResults, id: \.id) { item in
                        inboxRow(item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectInboxItem(item)
                            }

                        Divider()
                            .overlay(Color.wpBorder)
                            .padding(.leading, WPSpacing.md)
                    }
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.wpCaption.weight(.semibold))
            .foregroundStyle(Color.wpTextSecondary)
            .tracking(0.5)
            .padding(.horizontal, WPSpacing.md)
            .padding(.top, WPSpacing.lg)
            .padding(.bottom, WPSpacing.xs)
    }

    // MARK: - Ledger Row

    private func ledgerRow(_ transaction: ExpenseTransaction) -> some View {
        HStack(alignment: .top, spacing: WPSpacing.sm) {
            // Left content
            VStack(alignment: .leading, spacing: WPSpacing.xxs) {
                // Title with highlighted search term
                Text(highlightedTitle(transaction.title))
                    .font(.wpBody)
                    .lineLimit(1)

                // Date + @category
                HStack(spacing: WPSpacing.xxs) {
                    Text(Self.dateFormatter.string(from: transaction.date))
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextSecondary)

                    if let categoryName = viewModel.categoryNames[transaction.categoryId] {
                        Text("@\(categoryName)")
                            .font(.wpCaption)
                            .foregroundStyle(Color.wpPrimary)
                    }
                }
            }

            Spacer(minLength: WPSpacing.xs)

            // Amount — right-aligned
            Text(viewModel.currencyFormatter.format(transaction.amountCents))
                .font(.wpAmount)
                .foregroundStyle(transaction.amountCents < 0 ? Color.wpExpense : Color.wpIncome)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, WPSpacing.md)
        .padding(.vertical, WPSpacing.sm)
    }

    // MARK: - Inbox Row

    private func inboxRow(_ item: ExpenseTransactionInbox) -> some View {
        HStack(alignment: .top, spacing: WPSpacing.sm) {
            // Status dot
            let isComplete = item.amountCents != nil && item.accountId != nil && item.categoryId != nil
            Circle()
                .fill(isComplete ? Color.wpSuccess : Color.wpWarning)
                .frame(width: 8, height: 8)
                .padding(.top, 6) // Align with first line of text

            // Left content
            VStack(alignment: .leading, spacing: WPSpacing.xxs) {
                let displayTitle = item.title == TransactionDescriptionService.untitledPlaceholder ? "Untitled" : item.title
                Text(highlightedTitle(displayTitle))
                    .font(.wpBody)
                    .lineLimit(1)

                // Missing fields caption
                let missingFields = inboxMissingFields(item)
                if !missingFields.isEmpty {
                    Text("Missing \(missingFields)")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpWarning)
                }
            }

            Spacer(minLength: WPSpacing.xs)

            // Amount
            Text(viewModel.currencyFormatter.formatOptional(item.amountCents))
                .font(.wpAmount)
                .foregroundStyle(Color.wpTextPrimary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, WPSpacing.md)
        .padding(.vertical, WPSpacing.sm)
    }

    // MARK: - Helpers

    private func highlightedTitle(_ title: String) -> AttributedString {
        var attributed = AttributedString(title)
        let query = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return attributed }

        let lowercased = title.lowercased()
        let queryLower = query.lowercased()
        var searchStart = lowercased.startIndex

        while searchStart < lowercased.endIndex,
              let range = lowercased.range(of: queryLower, range: searchStart..<lowercased.endIndex) {
            // Convert String range to AttributedString range
            if let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
               let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[attrStart..<attrEnd].backgroundColor = Color.wpPrimary.opacity(0.12)
            }
            searchStart = range.upperBound
        }

        return attributed
    }

    private func inboxMissingFields(_ item: ExpenseTransactionInbox) -> String {
        var missing: [String] = []
        if item.amountCents == nil { missing.append("amount") }
        if item.accountId == nil { missing.append("account") }
        if item.categoryId == nil { missing.append("category") }
        if item.date == nil { missing.append("date") }
        return missing.joined(separator: ", ")
    }

    // MARK: - Detail Sheet

    @ViewBuilder
    private var detailSheet: some View {
        if let ledgerItem = viewModel.selectedLedgerItem {
            TransactionDetailView(
                viewModel: detailViewModelFactory(),
                mode: .ledger(ledgerItem),
                onDismiss: { viewModel.dismissDetail() }
            )
            .presentationDetents([.medium, .large])
        } else if let inboxItem = viewModel.selectedInboxItem {
            TransactionDetailView(
                viewModel: detailViewModelFactory(),
                mode: .inbox(inboxItem),
                onDismiss: { viewModel.dismissDetail() }
            )
            .presentationDetents([.medium, .large])
        }
    }
}
