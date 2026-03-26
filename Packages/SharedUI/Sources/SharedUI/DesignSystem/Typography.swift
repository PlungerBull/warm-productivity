import SwiftUI

// MARK: - Typography Scale (SF Pro)

public extension Font {
    /// Large titles — screen headers.
    static let wpLargeTitle = Font.system(.largeTitle, design: .default, weight: .bold)

    /// Title — section headers, modal titles.
    static let wpTitle = Font.system(.title2, design: .default, weight: .semibold)

    /// Headline — row titles, emphasized text.
    static let wpHeadline = Font.system(.headline, design: .default, weight: .semibold)

    /// Subheadline — section labels, sidebar headers.
    static let wpSubheadline = Font.system(.subheadline, design: .default, weight: .medium)

    /// Body — primary content text.
    static let wpBody = Font.system(.body, design: .default)

    /// Callout — secondary content, descriptions.
    static let wpCallout = Font.system(.callout, design: .default)

    /// Caption — metadata, timestamps, helper text.
    static let wpCaption = Font.system(.caption, design: .default)

    /// Caption 2 — smallest text, badges.
    static let wpCaption2 = Font.system(.caption2, design: .default)

    /// Monospaced numbers — amounts, balances. Tabular alignment for columns.
    static let wpAmount = Font.system(.body, design: .default, weight: .medium).monospacedDigit()

    /// Compact monospaced numbers — transaction row amounts.
    static let wpAmountCompact = Font.system(.callout, design: .default, weight: .medium).monospacedDigit()

    /// Large monospaced numbers — summary totals, balance cards.
    static let wpAmountLarge = Font.system(.title2, design: .default, weight: .semibold).monospacedDigit()

    /// Large icon — decorative SF Symbols on auth/onboarding screens.
    static let wpIconLarge = Font.system(size: 72, weight: .light)

    /// Medium icon — decorative SF Symbols on secondary screens.
    static let wpIconMedium = Font.system(size: 56, weight: .light)

    /// Small icon — inline SF Symbols in chips and badges.
    static let wpIconSmall = Font.system(size: 10, weight: .regular)

    /// Decorative icon — empty state / import screen illustrations.
    static let wpIconDecorative = Font.system(size: 48, weight: .light)

    // MARK: - Hero (transaction detail sheet)

    /// Hero title — transaction name in expanded detail sheet.
    static let wpHeroTitle = Font.system(size: 20, weight: .bold)

    /// Hero amount — sign and digits in expanded detail sheet.
    static let wpHeroAmount = Font.system(size: 36, weight: .bold).monospacedDigit()

    /// Hero currency code — ISO code beside hero amount.
    static let wpHeroCurrencyCode = Font.system(size: 18, weight: .bold)

    /// Compact title — transaction name in collapsed detail sheet.
    static let wpCompactTitle = Font.system(size: 17, weight: .bold)

    /// Compact amount — sign and digits in collapsed detail sheet.
    static let wpCompactAmount = Font.system(size: 28, weight: .bold).monospacedDigit()

    /// Compact currency code — ISO code beside compact amount.
    static let wpCompactCurrencyCode = Font.system(size: 14, weight: .bold)

    // MARK: - UI Controls

    /// Pill label — text inside toolbar pills (date, category, account, hashtag).
    static let wpPillLabel = Font.system(size: 13, weight: .medium)

    /// Section chevron — expand/collapse arrow in sidebar sections.
    static let wpSectionChevron = Font.system(size: 10, weight: .semibold)

    /// Section header — uppercase section title in sidebar.
    static let wpSectionHeader = Font.system(size: 11, weight: .semibold)

    /// Action icon — small interactive icons (plus, edit) in section headers.
    static let wpActionIcon = Font.system(size: 14, weight: .medium)

    /// Nav chevron — back navigation arrow.
    static let wpNavChevron = Font.system(size: 16, weight: .semibold)
}
