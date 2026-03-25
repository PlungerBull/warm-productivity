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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: WPSpacing.xs) {
                    Text("Let's get you started.")
                        .font(.wpLargeTitle)
                        .foregroundStyle(Color.wpTextPrimary)

                    Text("Two quick things and you're in.")
                        .font(.wpBody)
                        .foregroundStyle(Color.wpTextSecondary)
                }
                .padding(.top, WPSpacing.xxl)
                .padding(.horizontal, WPSpacing.lg)

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.clearError()
                    }
                    .padding(.horizontal, WPSpacing.lg)
                    .padding(.top, WPSpacing.md)
                }

                if viewModel.isLoadingCurrencies {
                    LoadingView(message: "Loading currencies...")
                        .padding(.top, WPSpacing.xxl)
                } else {
                    // Form fields
                    VStack(alignment: .leading, spacing: WPSpacing.xl) {
                        // Currency picker
                        VStack(alignment: .leading, spacing: WPSpacing.xs) {
                            Text("Home Currency")
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
                                        Text("\(currency.name) (\(currency.code))")
                                            .font(.wpBody)
                                            .foregroundStyle(Color.wpTextPrimary)
                                    } else {
                                        Text("Select currency")
                                            .font(.wpBody)
                                            .foregroundStyle(Color.wpTextTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.wpCaption)
                                        .foregroundStyle(Color.wpTextTertiary)
                                }
                                .padding(.horizontal, WPSpacing.md)
                                .padding(.vertical, WPSpacing.sm)
                                .background(Color.wpSurface)
                                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: WPCornerRadius.small)
                                        .stroke(Color.wpBorder, lineWidth: 0.5)
                                )
                            }
                        }

                        // Bank account name
                        VStack(alignment: .leading, spacing: WPSpacing.xs) {
                            Text("First Bank Account")
                                .font(.wpSubheadline)
                                .foregroundStyle(Color.wpTextSecondary)

                            TextField("e.g., Chase Checking", text: $viewModel.bankAccountName)
                                .font(.wpBody)
                                .padding(.horizontal, WPSpacing.md)
                                .padding(.vertical, WPSpacing.sm)
                                .background(Color.wpSurface)
                                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: WPCornerRadius.small)
                                        .stroke(Color.wpBorder, lineWidth: 0.5)
                                )
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .accessibilityLabel("Bank account name")
                        }
                    }
                    .padding(.horizontal, WPSpacing.lg)
                    .padding(.top, WPSpacing.xl)

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
                                .tint(Color.wpOnPrimary)
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
                    .background(Color.wpPrimary)
                    .opacity(viewModel.isValid ? 1.0 : 0.4)
                    .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                    .disabled(!viewModel.isValid || viewModel.isCompleting)
                    .padding(.horizontal, WPSpacing.lg)
                    .padding(.bottom, WPSpacing.xl)
                    .accessibilityLabel("Get Started")
                    .accessibilityHint(viewModel.isValid ? "Complete setup" : "Fill in all fields first")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
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
                HStack(spacing: WPSpacing.sm) {
                    Text(currency.code)
                        .font(.wpHeadline)
                        .foregroundStyle(Color.wpTextPrimary)
                        .frame(width: 44, alignment: .leading)
                    Text(currency.name)
                        .font(.wpBody)
                        .foregroundStyle(Color.wpTextSecondary)
                    Spacer()
                    if currency.code == selectedCode {
                        Image(systemName: "checkmark")
                            .font(.wpBody)
                            .foregroundStyle(Color.wpPrimary)
                    }
                }
                .contentShape(Rectangle())
            }
        }
        .searchable(text: $searchText, prompt: "Search currencies")
        .navigationTitle("Select Currency")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
