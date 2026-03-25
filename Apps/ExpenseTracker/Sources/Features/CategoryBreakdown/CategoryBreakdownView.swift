import SwiftUI
import SharedUI

struct CategoryBreakdownView: View {
    @State private var viewModel: CategoryBreakdownViewModel

    init(viewModel: CategoryBreakdownViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: WPSpacing.lg) {
                // MARK: - Period Picker
                periodPicker
                    .padding(.horizontal, WPSpacing.md)
                    .padding(.top, WPSpacing.xs)

                // MARK: - Summary Card
                summaryCard
                    .padding(.horizontal, WPSpacing.md)

                // MARK: - Category Breakdown
                if viewModel.items.isEmpty {
                    emptyState
                        .padding(.top, WPSpacing.xl)
                } else {
                    categoryList
                        .padding(.horizontal, WPSpacing.md)
                }
            }
            .padding(.bottom, WPSpacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(.background)
        .navigationTitle("Category Breakdown")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)
        .task {
            viewModel.load()
        }
        .onChange(of: viewModel.selectedPeriod) {
            viewModel.load()
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(CategoryBreakdownViewModel.BreakdownPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let net = viewModel.totalIncomeCents + viewModel.totalSpendCents

        return VStack(spacing: 0) {
            // Net amount — hero number
            VStack(spacing: WPSpacing.xxs) {
                Text("Net")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(viewModel.currencyFormatter.formatSigned(net))
                    .font(.wpAmountLarge)
                    .foregroundStyle(net >= 0 ? Color.wpIncome : Color.wpExpense)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WPSpacing.md)

            Divider()
                .overlay(Color.wpBorder)

            // Income / Expenses row
            HStack(spacing: 0) {
                // Income column
                VStack(spacing: WPSpacing.xxs) {
                    Text("Income")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)

                    Text(viewModel.currencyFormatter.format(viewModel.totalIncomeCents))
                        .font(.wpAmountCompact)
                        .foregroundStyle(Color.wpIncome)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, WPSpacing.sm)

                // Vertical separator
                Rectangle()
                    .fill(Color.wpBorder)
                    .frame(width: 0.5, height: 32)

                // Expenses column
                VStack(spacing: WPSpacing.xxs) {
                    Text("Expenses")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)

                    Text(viewModel.currencyFormatter.format(viewModel.totalSpendCents))
                        .font(.wpAmountCompact)
                        .foregroundStyle(Color.wpExpense)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, WPSpacing.sm)
            }
        }
        .background(Color.wpSurface)
        .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: WPSpacing.md) {
            Image(systemName: "chart.pie")
                .font(.wpIconDecorative)
                .foregroundStyle(Color.wpTextTertiary)

            Text("No expenses in this period")
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WPSpacing.xxl)
    }

    // MARK: - Category List

    private var categoryList: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Expenses by Category")
                    .font(.wpCaption.weight(.medium))
                    .foregroundStyle(Color.wpTextTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Text("\(viewModel.items.count) \(viewModel.items.count == 1 ? "category" : "categories")")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
            }
            .padding(.bottom, WPSpacing.xs)

            // Category rows in card
            VStack(spacing: 0) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    categoryRow(item)

                    if index < viewModel.items.count - 1 {
                        Divider()
                            .overlay(Color.wpBorder)
                            .padding(.leading, WPSpacing.md + 12 + WPSpacing.sm) // Align with text after dot
                    }
                }
            }
            .background(Color.wpSurface)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
        }
    }

    // MARK: - Category Row

    private func categoryRow(_ item: CategorySpendItem) -> some View {
        VStack(spacing: WPSpacing.xs) {
            HStack(spacing: WPSpacing.sm) {
                // Category color dot
                Circle()
                    .fill(Color(hex: item.color))
                    .frame(width: 12, height: 12)

                // Name + count
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.wpBody)
                        .foregroundStyle(Color.wpTextPrimary)
                        .lineLimit(1)

                    Text("\(item.transactionCount) transaction\(item.transactionCount == 1 ? "" : "s")")
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)
                }

                Spacer(minLength: WPSpacing.xs)

                // Amount + percentage
                VStack(alignment: .trailing, spacing: 1) {
                    Text(viewModel.currencyFormatter.format(item.spendCents))
                        .font(.wpAmountCompact)
                        .foregroundStyle(Color.wpExpense)
                        .fixedSize()

                    Text(String(format: "%.1f%%", item.percentage))
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.wpBorder.opacity(0.5))
                        .frame(height: 3)

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: item.color))
                        .frame(width: max(0, geometry.size.width * item.percentage / 100.0), height: 3)
                }
            }
            .frame(height: 3)
            .padding(.leading, 12 + WPSpacing.sm) // Align with text after dot
        }
        .padding(.horizontal, WPSpacing.md)
        .padding(.vertical, WPSpacing.sm)
    }
}
