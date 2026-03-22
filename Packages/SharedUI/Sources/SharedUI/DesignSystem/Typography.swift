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
}
