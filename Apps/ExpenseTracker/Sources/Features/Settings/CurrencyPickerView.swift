import SwiftUI
import SharedUI
import SharedModels

struct CurrencyPickerView: View {
    let currencies: [GlobalCurrency]
    let selectedCode: String
    let onSelect: (String) -> Void
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
                onSelect(currency.code)
                dismiss()
            } label: {
                HStack(spacing: WPSpacing.sm) {
                    if let flag = currency.flag {
                        Text(flag)
                            .font(.wpTitle)
                            .frame(width: 32, alignment: .center)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currency.code)
                            .font(.wpHeadline)
                            .foregroundStyle(Color.wpTextPrimary)
                        Text(currency.name)
                            .font(.wpCaption)
                            .foregroundStyle(Color.wpTextSecondary)
                    }
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
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Search currencies")
        .navigationTitle("Main Currency")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
    }
}
