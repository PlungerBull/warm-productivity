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
            // Compact header
            VStack(alignment: .leading, spacing: 2) {
                Button { dismiss() } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Transactions")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(Color.wpPrimary)
                }

                Text(destination.title)
                    .font(.wpTitle)
                    .foregroundStyle(Color.wpTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WPSpacing.md)
            .padding(.top, WPSpacing.xxs)
            .padding(.bottom, WPSpacing.sm)

            // Search bar (ledger only)
            if isLedger {
                searchBarPlaceholder
                    .padding(.horizontal, WPSpacing.md)
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
        .background(Color.wpBackground.ignoresSafeArea())
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

    // MARK: - Detail Sheet

    @ViewBuilder
    private var detailSheet: some View {
        if let inboxItem = viewModel.selectedInboxItem {
            TransactionDetailView(
                viewModel: detailViewModelFactory(),
                mode: .inbox(inboxItem),
                onDismiss: { viewModel.dismissDetail() }
            )
            .presentationDetents([.medium, .large])
        } else if let ledgerItem = viewModel.selectedLedgerItem {
            TransactionDetailView(
                viewModel: detailViewModelFactory(),
                mode: .ledger(ledgerItem),
                onDismiss: { viewModel.dismissDetail() }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Inbox Content

    @ViewBuilder
    private var inboxContent: some View {
        if viewModel.inboxItems.isEmpty {
            EmptyStateView(
                icon: "tray.and.arrow.down",
                title: "Inbox Empty",
                message: "No draft transactions. Tap + to add one."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.inboxItems, id: \.id) { item in
                        inboxRow(item)
                        Divider().padding(.leading, WPSpacing.md)
                    }
                }
            }
        }
    }

    private func inboxRow(_ item: ExpenseTransactionInbox) -> some View {
        let isUntitled = item.title == TransactionDescriptionService.untitledPlaceholder
        return TransactionRow(
            title: isUntitled ? "Untitled" : item.title,
            amount: viewModel.currencyFormatter.formatOptional(item.amountCents),
            isUntitled: isUntitled,
            style: .inbox(isReady: viewModel.isReadyToPromote(item))
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
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.ledgerItems, id: \.id) { transaction in
                        ledgerRow(transaction)
                        Divider().padding(.leading, WPSpacing.md)
                    }
                }
            }
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

    // MARK: - Search Bar Placeholder

    private var searchBarPlaceholder: some View {
        Button {
            // Trigger search via parent — currently search is a sheet from TransactionsTabView
        } label: {
            HStack(spacing: WPSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.wpTextTertiary)
                Text("Search transactions")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.wpTextTertiary)
                Spacer()
            }
            .padding(.horizontal, WPSpacing.sm)
            .padding(.vertical, 10)
            .background(Color.wpGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State Helpers

    private var emptyIcon: String {
        switch destination {
        case .inbox: "tray.and.arrow.down"
        case .ledger: "list.bullet"
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
