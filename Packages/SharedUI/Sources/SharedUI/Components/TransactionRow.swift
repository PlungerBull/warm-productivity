import SwiftUI

/// Standard row layout for transaction lists.
/// Placeholder — full implementation during Phase 1 UI.
public struct TransactionRow: View {
    let title: String
    let amount: String
    let date: String
    let category: String?

    public init(title: String, amount: String, date: String, category: String? = nil) {
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: WPSpacing.xxs) {
                Text(title)
                    .font(.wpBody)
                if let category {
                    Text(category)
                        .font(.wpCaption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: WPSpacing.xxs) {
                Text(amount)
                    .font(.wpBody.monospacedDigit())
                Text(date)
                    .font(.wpCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, WPSpacing.xs)
    }
}
