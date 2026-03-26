import SwiftUI
import SharedUI
import SharedModels
import SharedUtilities

struct TransactionListView: View {
    let destination: SidebarDestination
    @Bindable var viewModel: TransactionListViewModel
    let detailViewModelFactory: () -> TransactionDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private var isInbox: Bool {
        if case .inbox = destination { return true }
        return false
    }

    private var isLedger: Bool {
        if case .ledger = destination { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Search bar (ledger only)
            if isLedger {
                searchBar
                    .padding(.horizontal, WPSpacing.lg)
                    .padding(.bottom, WPSpacing.sm)
            }

            // Content
            if isInbox {
                inboxContent
            } else {
                ledgerContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .navigationBarHidden(true)
        .task {
            viewModel.load(destination: destination)
        }
        .onChange(of: destination) {
            viewModel.load(destination: destination)
        }
        .sheet(isPresented: $viewModel.showDetail, onDismiss: {
            viewModel.load(destination: destination)
        }) {
            detailSheet
        }
        .alert("Delete Transaction", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.performDelete()
            }
        } message: {
            Text("This transaction will be permanently removed.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: WPSpacing.xxs) {
            Button { dismiss() } label: {
                HStack(spacing: WPSpacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.wpNavChevron)
                    Text("Back")
                        .font(.wpBody)
                }
                .foregroundStyle(Color.wpPrimary)
            }
            .padding(.bottom, WPSpacing.xxs)

            HStack(alignment: .firstTextBaseline) {
                Text(destination.title)
                    .font(.wpLargeTitle)
                    .foregroundStyle(Color.wpTextPrimary)

                Spacer()

                // Item count badge
                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WPSpacing.lg)
        .padding(.top, WPSpacing.xs)
        .padding(.bottom, WPSpacing.sm)
    }

    private var itemCount: Int {
        isInbox ? viewModel.inboxItems.count : viewModel.ledgerItems.count
    }

    // MARK: - Detail Sheet

    @ViewBuilder
    private var detailSheet: some View {
        if let inboxItem = viewModel.selectedInboxItem {
            TransactionDetailView(
                viewModel: detailViewModelFactory(),
                mode: .inbox(inboxItem),
                onDismiss: { viewModel.dismissDetail() }
            )
        } else if let ledgerItem = viewModel.selectedLedgerItem {
            TransactionDetailView(
                viewModel: detailViewModelFactory(),
                mode: .ledger(ledgerItem),
                onDismiss: { viewModel.dismissDetail() }
            )
        }
    }

    // MARK: - Inbox Content

    @ViewBuilder
    private var inboxContent: some View {
        if viewModel.inboxItems.isEmpty {
            EmptyStateView(
                icon: "tray",
                title: "Inbox Empty",
                message: "Quick-add transactions land here as drafts. Fill in the details, then promote them to your ledger."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: WPSpacing.md) {
                    // Overdue section
                    let overdue = viewModel.overdueInboxItems
                    if !overdue.isEmpty {
                        inboxSection(title: "Overdue", items: overdue, tint: Color.wpError)
                    }

                    // Current section
                    let current = viewModel.currentInboxItems
                    if !current.isEmpty {
                        inboxSection(
                            title: overdue.isEmpty ? nil : "Current",
                            items: current,
                            tint: nil
                        )
                    }
                }
                .padding(.horizontal, WPSpacing.lg)
                .padding(.bottom, WPSpacing.xxl)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func inboxSection(title: String?, items: [ExpenseTransactionInbox], tint: Color?) -> some View {
        VStack(alignment: .leading, spacing: WPSpacing.xs) {
            if let title {
                HStack(spacing: WPSpacing.xxs) {
                    if let tint {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                    }
                    Text(title.uppercased())
                        .font(.wpCaption)
                        .foregroundStyle(tint ?? Color.wpTextTertiary)
                        .tracking(0.5)
                }
                .padding(.leading, WPSpacing.xxs)
                .padding(.bottom, WPSpacing.xxs)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    inboxRow(item)

                    if index < items.count - 1 {
                        Divider()
                            .foregroundStyle(Color.wpBorder)
                            .padding(.leading, WPSpacing.md)
                    }
                }
            }
            .background(Color.wpSurface)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
        }
    }

    private func inboxRow(_ item: ExpenseTransactionInbox) -> some View {
        let isUntitled = item.title == TransactionDescriptionService.untitledPlaceholder
        let accountName: String = {
            guard let accountId = item.accountId else { return "" }
            return viewModel.accountName(for: accountId)
        }()
        return TransactionRow(
            title: isUntitled ? "Untitled" : item.title,
            amount: viewModel.currencyFormatter.formatOptionalSigned(item.amountCents),
            isExpense: (item.amountCents ?? 0) < 0,
            isUntitled: isUntitled,
            style: .inbox(isReady: viewModel.isReadyToPromote(item), accountName: accountName)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectInboxItem(item)
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.confirmDeleteInbox(id: item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Ledger Content

    @ViewBuilder
    private var ledgerContent: some View {
        if viewModel.ledgerItems.isEmpty {
            EmptyStateView(
                icon: emptyIcon,
                title: "No Transactions",
                message: emptyMessage
            )
        } else {
            ScrollView {
                LazyVStack(spacing: WPSpacing.md) {
                    ForEach(viewModel.ledgerDateGroups) { group in
                        dateSection(group)
                    }
                }
                .padding(.horizontal, WPSpacing.lg)
                .padding(.bottom, WPSpacing.xxl)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func dateSection(_ group: DateGroup<ExpenseTransaction>) -> some View {
        VStack(alignment: .leading, spacing: WPSpacing.xs) {
            // Date header
            Text(group.label)
                .font(.wpCaption)
                .foregroundStyle(Color.wpTextTertiary)
                .tracking(0.3)
                .padding(.leading, WPSpacing.xxs)
                .padding(.bottom, WPSpacing.xxs)

            // Grouped card
            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, transaction in
                    ledgerRow(transaction)

                    if index < group.items.count - 1 {
                        Divider()
                            .foregroundStyle(Color.wpBorder)
                            .padding(.leading, WPSpacing.md)
                    }
                }
            }
            .background(Color.wpSurface)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
        }
    }

    private func ledgerRow(_ transaction: ExpenseTransaction) -> some View {
        TransactionRow(
            title: transaction.title,
            amount: viewModel.currencyFormatter.formatSigned(transaction.amountCents),
            isExpense: transaction.amountCents < 0,
            style: .ledger(
                categoryColor: viewModel.categoryColor(for: transaction.categoryId),
                accountName: viewModel.accountName(for: transaction.accountId)
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectLedgerItem(transaction)
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.confirmDeleteLedger(id: transaction.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        Button {
            // Trigger search via parent — currently search is a sheet from TransactionsTabView
        } label: {
            HStack(spacing: WPSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
                Text("Search transactions")
                    .font(.wpCallout)
                    .foregroundStyle(Color.wpTextTertiary)
                Spacer()
            }
            .padding(.horizontal, WPSpacing.sm)
            .padding(.vertical, WPSpacing.xs)
            .background(Color.wpSurface)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: WPCornerRadius.small)
                    .strokeBorder(Color.wpBorder.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State Helpers

    private var emptyIcon: String {
        switch destination {
        case .inbox: "tray"
        case .ledger: "list.bullet.rectangle"
        case .bankAccount: "building.columns"
        case .category: "folder"
        case .hashtag: "number"
        }
    }

    private var emptyMessage: String {
        switch destination {
        case .inbox: "No draft transactions."
        case .ledger: "No confirmed transactions yet. Tap + to add one."
        case .bankAccount: "No transactions for this account."
        case .category: "No transactions in this category."
        case .hashtag: "No transactions with this hashtag."
        }
    }
}
