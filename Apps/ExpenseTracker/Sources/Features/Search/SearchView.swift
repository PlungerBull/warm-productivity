import SwiftUI
import SharedUI
import SharedModels
import SharedUtilities

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    let detailViewModelFactory: () -> TransactionDetailViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Search Transactions",
                        message: "Search by title, category, account, hashtag, amount, or notes."
                    )
                } else if viewModel.results.isEmpty && viewModel.inboxResults.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No transactions match '\(viewModel.query)'."
                    )
                } else {
                    List {
                        if !viewModel.results.isEmpty {
                            Section("Ledger") {
                                ForEach(viewModel.results, id: \.id) { transaction in
                                    TransactionRow(
                                        title: transaction.title,
                                        amount: viewModel.currencyFormatter.format(transaction.amountCents),
                                        date: CurrencyFormatter.formatDate(transaction.date)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectLedgerItem(transaction)
                                    }
                                }
                            }
                        }

                        if !viewModel.inboxResults.isEmpty {
                            Section("Inbox") {
                                ForEach(viewModel.inboxResults, id: \.id) { item in
                                    TransactionRow(
                                        title: item.title == TransactionDescriptionService.untitledPlaceholder ? "Untitled" : item.title,
                                        amount: viewModel.currencyFormatter.formatOptional(item.amountCents),
                                        date: item.date.map { CurrencyFormatter.formatDate($0) } ?? "No date"
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectInboxItem(item)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Search transactions...")
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
            }
        }
    }

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
