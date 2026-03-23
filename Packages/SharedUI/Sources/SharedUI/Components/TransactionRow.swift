import SwiftUI

// MARK: - Transaction Row

/// Single-line transaction row used in ledger and inbox flat lists.
///
/// Two styles:
/// - `.ledger`: Category color left border, title, account name, signed amount.
/// - `.inbox`: Green left border if ready to promote, no border if not. Title, optional account name, amount.
public struct TransactionRow: View {
    let title: String
    let amount: String
    let isExpense: Bool
    let isUntitled: Bool
    let style: Style

    public enum Style {
        /// Ledger row: category color border, account name shown.
        case ledger(categoryColor: Color, accountName: String)
        /// Inbox row: green border if ready, no border if not. Optional account name.
        case inbox(isReady: Bool, accountName: String = "")
    }

    public init(title: String, amount: String, isExpense: Bool = true, isUntitled: Bool = false, style: Style) {
        self.title = title
        self.amount = amount
        self.isExpense = isExpense
        self.isUntitled = isUntitled
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left border — category color (ledger) or green/clear (inbox)
            Rectangle()
                .fill(borderColor ?? Color.clear)
                .frame(width: 3)

            // Row content
            HStack {
                Text(title)
                    .font(isUntitled ? Font.wpBody.italic() : .wpBody)
                    .foregroundStyle(isUntitled ? Color.wpTextTertiary : Color.wpTextPrimary)
                    .lineLimit(1)

                Spacer(minLength: WPSpacing.xs)

                // Account name — shown for both ledger and inbox (when available)
                if !accountName.isEmpty {
                    Text(accountName)
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)
                        .lineLimit(1)
                        .layoutPriority(-1)
                }

                // Amount — right-aligned, never truncates
                Text(amount)
                    .font(.wpAmount)
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.leading, 13)
            .padding(.trailing, WPSpacing.md)
            .padding(.vertical, WPSpacing.sm)
        }
    }

    private var accountName: String {
        switch style {
        case .ledger(_, let name): name
        case .inbox(_, let name): name
        }
    }

    private var amountColor: Color {
        switch style {
        case .ledger:
            isExpense ? Color.wpExpense : Color.wpIncome
        case .inbox:
            Color.wpTextPrimary
        }
    }

    private var borderColor: Color? {
        switch style {
        case .ledger(let categoryColor, _):
            categoryColor
        case .inbox(let isReady, _):
            isReady ? Color.wpSuccess : nil
        }
    }
}
