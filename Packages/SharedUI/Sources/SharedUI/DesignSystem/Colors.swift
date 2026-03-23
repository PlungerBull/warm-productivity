import SwiftUI

// MARK: - Brand Colors

public extension Color {
    /// Primary brand color — brick orange. Used for primary actions, active states, key UI elements.
    static let wpPrimary = Color(light: Color(hex: "#c2410c"), dark: Color(hex: "#ea580c"))

    /// Secondary accent — warm amber. Used for secondary actions and highlights.
    static let wpSecondary = Color(light: Color(hex: "#b45309"), dark: Color(hex: "#d97706"))

    /// Background — clean white (light), warm dark gray (dark). Never pure black.
    static let wpBackground = Color(light: Color(hex: "#ffffff"), dark: Color(hex: "#1c1917"))

    /// Surface — cards, sheets, elevated containers.
    static let wpSurface = Color(light: Color(hex: "#fafaf9"), dark: Color(hex: "#292524"))

    /// Grouped background — for grouped table/list backgrounds.
    static let wpGroupedBackground = Color(light: Color(hex: "#f5f5f4"), dark: Color(hex: "#1c1917"))

    /// Error — destructive actions, validation errors, over-budget states.
    static let wpError = Color(light: Color(hex: "#dc2626"), dark: Color(hex: "#ef4444"))

    /// Success — positive confirmations, income amounts, within-budget states.
    static let wpSuccess = Color(light: Color(hex: "#16a34a"), dark: Color(hex: "#22c55e"))

    /// Warning — amber. Budget 80-99%, near-limit states, draft badges.
    static let wpWarning = Color(light: Color(hex: "#d97706"), dark: Color(hex: "#f59e0b"))

    /// Hashtag blue — used for # symbols in sidebar, tag chips, and search highlights.
    static let wpHashtag = Color(light: Color(hex: "#4f6bed"), dark: Color(hex: "#6b8af2"))
}

// MARK: - Semantic Colors

public extension Color {
    /// Income amounts (positive transactions). Alias for success.
    static let wpIncome = Color.wpSuccess

    /// Expense amounts (negative transactions). Alias for error.
    static let wpExpense = Color.wpError

    /// Primary text color.
    static let wpTextPrimary = Color(light: Color(hex: "#1c1917"), dark: Color(hex: "#fafaf9"))

    /// Secondary text — subtitles, helper text, metadata.
    static let wpTextSecondary = Color(light: Color(hex: "#78716c"), dark: Color(hex: "#a8a29e"))

    /// Tertiary text — placeholders, disabled states.
    static let wpTextTertiary = Color(light: Color(hex: "#a8a29e"), dark: Color(hex: "#78716c"))

    /// Dividers and borders.
    static let wpBorder = Color(light: Color(hex: "#e7e5e4"), dark: Color(hex: "#44403c"))

    /// Text/icons on primary-colored backgrounds.
    static let wpOnPrimary = Color.white
}

// MARK: - Adaptive Color Helper

extension Color {
    public init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
