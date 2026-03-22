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
        }
        .searchable(text: $searchText, prompt: "Search currencies")
        .navigationTitle("Main Currency")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
    }
}
