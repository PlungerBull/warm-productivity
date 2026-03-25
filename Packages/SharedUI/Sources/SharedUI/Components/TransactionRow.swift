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
            RoundedRectangle(cornerRadius: 1.5)
                .fill(borderColor ?? Color.clear)
                .frame(width: 3)
                .padding(.vertical, WPSpacing.xxs)

            // Row content
            HStack(spacing: WPSpacing.xs) {
                Text(title)
                    .font(isUntitled ? Font.wpCallout.italic() : .wpCallout)
                    .foregroundStyle(isUntitled ? Color.wpTextTertiary : Color.wpTextPrimary)
                    .lineLimit(1)

                Spacer(minLength: WPSpacing.xs)

                // Account name — shown for both ledger and inbox (when available)
                if !accountName.isEmpty {
                    Text(accountName)
                        .font(.wpCaption)
                        .foregroundStyle(Color.wpTextTertiary)
                        .lineLimit(1)
                        .fixedSize()
                }

                // Amount — right-aligned, never truncates
                Text(amount)
                    .font(.wpAmountCompact)
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.leading, WPSpacing.sm)
            .padding(.trailing, WPSpacing.md)
            .padding(.vertical, 10)
        }
    }

    private var accountName: String {
        switch style {
        case .ledger(_, let name): name
        case .inbox(_, let name): name
        }
    }

    private var amountColor: Color {
        isExpense ? Color.wpExpense : Color.wpIncome
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
