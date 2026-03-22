import SwiftUI
import SharedUI
import SharedModels
import SharedUtilities

struct TransactionListView: View {
    let destination: SidebarDestination
    @Bindable var viewModel: TransactionListViewModel
    let detailViewModelFactory: () -> TransactionDetailViewModel

    private var isInbox: Bool {
        if case .inbox = destination { return true }
        return false
    }

    var body: some View {
        Group {
            if isInbox {
                inboxContent
            } else {
                ledgerContent
            }
        }
        .navigationTitle(destination.title)
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
                icon: "tray",
                title: "Inbox Empty",
                message: "No draft transactions. Tap + to add one."
            )
        } else {
            List {
                // Overdue section
                if !viewModel.overdueInboxItems.isEmpty {
                    Section {
                        DisclosureGroup("Overdue (\(viewModel.overdueInboxItems.count))") {
                            ForEach(viewModel.overdueInboxItems, id: \.id) { item in
                                inboxRow(item)
                                    .listRowBackground(Color.wpWarning.opacity(0.05))
                            }
                        }
                    }
                }

                // Current items
                Section {
                    ForEach(viewModel.currentInboxItems, id: \.id) { item in
                        inboxRow(item)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func inboxRow(_ item: ExpenseTransactionInbox) -> some View {
        TransactionRow(
            title: item.title == TransactionDescriptionService.untitledPlaceholder ? "Untitled" : item.title,
            amount: viewModel.currencyFormatter.formatOptional(item.amountCents),
            date: item.date.map { CurrencyFormatter.formatDate($0) } ?? "No date"
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectInboxItem(item)
        }
        .swipeActions(edge: .trailing) {
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
            List {
                ForEach(viewModel.ledgerDateGroups) { group in
                    Section(group.label) {
                        ForEach(group.items, id: \.id) { transaction in
                            ledgerRow(transaction)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func ledgerRow(_ transaction: ExpenseTransaction) -> some View {
        TransactionRow(
            title: transaction.title,
            amount: viewModel.currencyFormatter.format(transaction.amountCents),
            date: CurrencyFormatter.formatDate(transaction.date)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectLedgerItem(transaction)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.confirmDeleteLedger(id: transaction.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State Helpers

    private var emptyIcon: String {
        switch destination {
        case .inbox: "tray"
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
