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
                        .font(.wpCallout)

                    TextField("Search transactions...", text: $viewModel.query)
                        .font(.wpBody)
                        .foregroundStyle(Color.wpTextPrimary)
                        .focused($isSearchFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)

                    if !viewModel.query.isEmpty {
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                viewModel.query = ""
                                viewModel.search()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.wpTextTertiary)
                                .font(.wpCallout)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, WPSpacing.sm)
                .padding(.vertical, 10)
                .background(Color.wpSurface)
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))

                Button("Cancel") {
                    dismiss()
                }
                .font(.wpBody)
                .foregroundStyle(Color.wpPrimary)
            }
            .padding(.horizontal, WPSpacing.md)
            .padding(.top, WPSpacing.md)
            .padding(.bottom, WPSpacing.sm)

            // MARK: - Content
            if viewModel.query.isEmpty {
                emptySearchState
            } else if viewModel.results.isEmpty && viewModel.inboxResults.isEmpty {
                noResultsState
            } else {
                resultsList
            }
        }
        .background(.clear)
        .animation(.easeInOut(duration: 0.2), value: viewModel.query.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: viewModel.results.count)
        .animation(.easeInOut(duration: 0.2), value: viewModel.inboxResults.count)
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
                .padding(.bottom, WPSpacing.xxs)

            Text("Search Transactions")
                .font(.wpHeadline)
                .foregroundStyle(Color.wpTextPrimary)

            Text("Search by title, category, account,\nhashtag, amount, or notes.")
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WPSpacing.xl)
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack(spacing: WPSpacing.md) {
            Spacer()

            Image(systemName: "text.magnifyingglass")
                .font(.wpIconDecorative)
                .foregroundStyle(Color.wpTextTertiary)
                .padding(.bottom, WPSpacing.xxs)

            Text("No Results")
                .font(.wpHeadline)
                .foregroundStyle(Color.wpTextPrimary)

            Text("No matches for \"\(viewModel.query)\".\nTry a different search term.")
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WPSpacing.xl)
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Result count summary
                resultsSummary
                    .padding(.horizontal, WPSpacing.md)
                    .padding(.top, WPSpacing.sm)
                    .padding(.bottom, WPSpacing.xxs)

                // Ledger Section
                if !viewModel.results.isEmpty {
                    sectionHeader("Ledger")

                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, transaction in
                            ledgerRow(transaction)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectLedgerItem(transaction)
                                }

                            if index < viewModel.results.count - 1 {
                                Divider()
                                    .overlay(Color.wpBorder)
                                    .padding(.leading, WPSpacing.md)
                            }
                        }
                    }
                    .background(Color.wpSurface)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                    .padding(.horizontal, WPSpacing.md)
                }

                // Inbox Section
                if !viewModel.inboxResults.isEmpty {
                    sectionHeader("Inbox")

                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.inboxResults.enumerated()), id: \.element.id) { index, item in
                            inboxRow(item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectInboxItem(item)
                                }

                            if index < viewModel.inboxResults.count - 1 {
                                Divider()
                                    .overlay(Color.wpBorder)
                                    .padding(.leading, WPSpacing.md)
                            }
                        }
                    }
                    .background(Color.wpSurface)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                    .padding(.horizontal, WPSpacing.md)
                }

                // Bottom spacing
                Spacer()
                    .frame(height: WPSpacing.xl)
            }
        }
    }

    // MARK: - Results Summary

    private var resultsSummary: some View {
        let total = viewModel.results.count + viewModel.inboxResults.count
        return Text("\(total) \(total == 1 ? "result" : "results")")
            .font(.wpCaption)
            .foregroundStyle(Color.wpTextTertiary)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.wpCaption.weight(.medium))
            .foregroundStyle(Color.wpTextTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, WPSpacing.md)
            .padding(.top, WPSpacing.lg)
            .padding(.bottom, WPSpacing.xs)
    }

    // MARK: - Ledger Row

    private func ledgerRow(_ transaction: ExpenseTransaction) -> some View {
        HStack(alignment: .center, spacing: WPSpacing.sm) {
            // Category color indicator
            if let color = viewModel.categoryColors[transaction.categoryId] {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: color))
                    .frame(width: 3, height: 32)
            }

            // Left content
            VStack(alignment: .leading, spacing: WPSpacing.xxs) {
                Text(highlightedTitle(transaction.title))
                    .font(.wpBody)
                    .lineLimit(1)

                HStack(spacing: WPSpacing.xxs) {
                    Text(Self.dateFormatter.string(from: transaction.date))
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)

                    if let categoryName = viewModel.categoryNames[transaction.categoryId] {
                        Text("\u{00B7}")
                            .font(.wpCaption)
                            .foregroundStyle(Color.wpTextTertiary)
                        Text("@\(categoryName)")
                            .font(.wpCaption)
                            .foregroundStyle(Color.wpTextSecondary)
                    }
                }
            }

            Spacer(minLength: WPSpacing.xs)

            // Amount
            Text(viewModel.currencyFormatter.formatSigned(transaction.amountCents))
                .font(.wpAmountCompact)
                .foregroundStyle(transaction.amountCents >= 0 ? Color.wpIncome : Color.wpExpense)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, WPSpacing.md)
        .padding(.vertical, WPSpacing.sm)
    }

    // MARK: - Inbox Row

    private func inboxRow(_ item: ExpenseTransactionInbox) -> some View {
        HStack(alignment: .center, spacing: WPSpacing.sm) {
            // Status indicator
            let isComplete = item.amountCents != nil && item.accountId != nil && item.categoryId != nil
            Circle()
                .fill(isComplete ? Color.wpSuccess : Color.wpWarning)
                .frame(width: 6, height: 6)

            // Left content
            VStack(alignment: .leading, spacing: WPSpacing.xxs) {
                let displayTitle = item.title == TransactionDescriptionService.untitledPlaceholder ? "Untitled" : item.title
                Text(highlightedTitle(displayTitle))
                    .font(.wpBody)
                    .lineLimit(1)

                let missingFields = inboxMissingFields(item)
                if !missingFields.isEmpty {
                    Text("Missing \(missingFields)")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpWarning)
                }
            }

            Spacer(minLength: WPSpacing.xs)

            // Amount
            Text(viewModel.currencyFormatter.formatOptionalSigned(item.amountCents))
                .font(.wpAmountCompact)
                .foregroundStyle((item.amountCents ?? 0) >= 0 ? Color.wpIncome : Color.wpExpense)
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
            if let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
               let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[attrStart..<attrEnd].foregroundColor = Color.wpPrimary
                attributed[attrStart..<attrEnd].font = .wpHeadline
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
            .presentationDetents([.fraction(0.75), .large])
        } else if let inboxItem = viewModel.selectedInboxItem {
            TransactionDetailView(
                viewModel: detailViewModelFactory(),
                mode: .inbox(inboxItem),
                onDismiss: { viewModel.dismissDetail() }
            )
            .presentationDetents([.fraction(0.75), .large])
        }
    }
}
