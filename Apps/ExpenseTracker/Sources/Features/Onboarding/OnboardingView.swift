import SwiftUI
import SharedUI
import SharedModels

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    let onSetupComplete: () -> Void

    init(viewModel: OnboardingViewModel, onSetupComplete: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSetupComplete = onSetupComplete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: WPSpacing.lg) {
                // Header
                VStack(spacing: WPSpacing.xs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.wpIconMedium)
                        .foregroundStyle(Color.wpPrimary)

                    Text("Welcome to Expense Tracker")
                        .font(.wpTitle)
                        .foregroundStyle(Color.wpTextPrimary)

                    Text("Let's get you set up.")
                        .font(.wpCallout)
                        .foregroundStyle(Color.wpTextSecondary)
                }
                .padding(.top, WPSpacing.xl)

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.clearError()
                    }
                }

                if viewModel.isLoadingCurrencies {
                    LoadingView(message: "Loading currencies...")
                } else {
                    // Form
                    VStack(alignment: .leading, spacing: WPSpacing.lg) {
                        // Currency picker
                        VStack(alignment: .leading, spacing: WPSpacing.xs) {
                            Text("Main Currency")
                                .font(.wpSubheadline)
                                .foregroundStyle(Color.wpTextSecondary)

                            NavigationLink {
                                CurrencyPickerList(
                                    currencies: viewModel.currencies,
                                    selectedCode: $viewModel.selectedCurrencyCode
                                )
                            } label: {
                                HStack {
                                    if let currency = viewModel.currencies.first(where: { $0.code == viewModel.selectedCurrencyCode }) {
                                        Text("\(currency.flag ?? "") \(currency.code) — \(currency.name)")
                                            .font(.wpBody)
                                            .foregroundStyle(Color.wpTextPrimary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.wpCaption)
                                        .foregroundStyle(Color.wpTextTertiary)
                                }
                                .padding(WPSpacing.sm)
                                .background(Color.wpSurface)
                                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: WPCornerRadius.small)
                                        .stroke(Color.wpBorder, lineWidth: 1)
                                )
                            }
                        }

                        // Bank account name
                        VStack(alignment: .leading, spacing: WPSpacing.xs) {
                            Text("First Bank Account")
                                .font(.wpSubheadline)
                                .foregroundStyle(Color.wpTextSecondary)

                            TextField("e.g. Chase, BCP PEN...", text: $viewModel.bankAccountName)
                                .font(.wpBody)
                                .padding(WPSpacing.sm)
                                .background(Color.wpSurface)
                                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: WPCornerRadius.small)
                                        .stroke(Color.wpBorder, lineWidth: 1)
                                )
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .accessibilityLabel("Bank account name")
                        }
                    }
                    .padding(.horizontal, WPSpacing.md)

                    Spacer()

                    // Get Started button
                    Button {
                        do {
                            try viewModel.completeSetup()
                            onSetupComplete()
                        } catch {
                            // Error is already set in viewModel
                        }
                    } label: {
                        if viewModel.isCompleting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Get Started")
                                .font(.wpHeadline)
                                .foregroundStyle(Color.wpOnPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(viewModel.isValid ? Color.wpPrimary : Color.wpTextTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                    .disabled(!viewModel.isValid || viewModel.isCompleting)
                    .padding(.horizontal, WPSpacing.md)
                    .padding(.bottom, WPSpacing.xl)
                    .accessibilityLabel("Get Started")
                    .accessibilityHint(viewModel.isValid ? "Complete setup" : "Fill in all fields first")
                }
            }
            .background(Color.wpBackground)
            .navigationBarHidden(true)
            .task {
                await viewModel.loadCurrencies()
            }
        }
    }
}

// MARK: - Currency Picker List

private struct CurrencyPickerList: View {
    let currencies: [GlobalCurrency]
    @Binding var selectedCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filtered: [GlobalCurrency] {
        if searchText.isEmpty { return currencies }
        let query = searchText.lowercased()
        return currencies.filter {
            $0.code.lowercased().contains(query)
                || $0.name.lowercased().contains(query)
        }
    }

    var body: some View {
        List(filtered, id: \.code) { currency in
            Button {
                selectedCode = currency.code
                dismiss()
            } label: {
                HStack {
                    Text("\(currency.flag ?? "") \(currency.code)")
                        .font(.wpHeadline)
                        .foregroundStyle(Color.wpTextPrimary)
                    Text(currency.name)
                        .font(.wpBody)
                        .foregroundStyle(Color.wpTextSecondary)
                    Spacer()
                    if currency.code == selectedCode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.wpPrimary)
                    }
                }
            }
            .listRowBackground(Color.wpSurface)
        }
        .searchable(text: $searchText, prompt: "Search currencies")
        .navigationTitle("Select Currency")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .background(Color.wpBackground)
    }
}
