import SwiftUI
import SharedUI

struct CategoryBreakdownView: View {
    @State private var viewModel: CategoryBreakdownViewModel

    init(viewModel: CategoryBreakdownViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            // Period picker
            Section {
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(CategoryBreakdownViewModel.BreakdownPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal, WPSpacing.md)
                .padding(.vertical, WPSpacing.xs)
            }

            // Totals
            Section {
                HStack {
                    Text("Total Expenses")
                        .font(.wpBody)
                    Spacer()
                    Text(viewModel.currencyFormatter.format(viewModel.totalSpendCents))
                        .font(.wpHeadline)
                        .foregroundStyle(Color.wpExpense)
                }
                HStack {
                    Text("Total Income")
                        .font(.wpBody)
                    Spacer()
                    Text(viewModel.currencyFormatter.format(viewModel.totalIncomeCents))
                        .font(.wpHeadline)
                        .foregroundStyle(Color.wpIncome)
                }
                HStack {
                    Text("Net")
                        .font(.wpBody)
                    Spacer()
                    let net = viewModel.totalIncomeCents + viewModel.totalSpendCents
                    Text(viewModel.currencyFormatter.format(net))
                        .font(.wpHeadline)
                        .foregroundStyle(net >= 0 ? Color.wpIncome : Color.wpExpense)
                }
            }

            // Category breakdown
            if viewModel.items.isEmpty {
                Section {
                    Text("No expenses in this period")
                        .font(.wpCallout)
                        .foregroundStyle(Color.wpTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, WPSpacing.lg)
                }
            } else {
                Section("Expenses by Category") {
                    ForEach(viewModel.items) { item in
                        HStack(spacing: WPSpacing.sm) {
                            Circle()
                                .fill(Color(hex: item.color))
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.wpBody)
                                Text("\(item.transactionCount) transaction\(item.transactionCount == 1 ? "" : "s")")
                                    .font(.wpCaption)
                                    .foregroundStyle(Color.wpTextTertiary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.currencyFormatter.format(item.spendCents))
                                    .font(.wpBody.monospacedDigit())
                                    .foregroundStyle(Color.wpExpense)
                                Text(String(format: "%.1f%%", item.percentage))
                                    .font(.wpCaption)
                                    .foregroundStyle(Color.wpTextSecondary)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Category Breakdown")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load()
        }
        .onChange(of: viewModel.selectedPeriod) {
            viewModel.load()
        }
    }
}
