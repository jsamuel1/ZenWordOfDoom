import SwiftUI
import UIKit

/// Fixed, scheme-independent color pairs with WCAG-verified contrast.
///
/// These pairs deliberately opt out of `.primary`/`.accentColor`/system
/// materials for the two spots in the app where a scheme-adaptive color
/// produced a near-invisible pairing (wheel tiles in dark mode, solved
/// crossword letters). Every pair here is pinned by `WCAGContrastTests` —
/// change a value, run the tests.
enum AccessibilityPalette {
    // MARK: - Wheel tiles (fixed light tile, fixed dark letter — scheme-independent)

    static let wheelTileFill = Color(.sRGB, white: 1, opacity: 0.9)
    static let wheelTileText = Color(.sRGB, white: 0.12, opacity: 1)
    static let wheelTileSelectedFill = Color(.sRGB, red: 0.0, green: 0.35, blue: 0.65, opacity: 1)
    static let wheelTileSelectedText = Color.white

    // MARK: - Crossword cells

    static let gridSolvedFill = Color(.sRGB, red: 0.85, green: 0.94, blue: 0.86, opacity: 1)
    static let gridSolvedText = Color(.sRGB, red: 0.05, green: 0.38, blue: 0.13, opacity: 1)
    static let gridUnfilledFill = Color(.sRGB, white: 1, opacity: 0.72)
    static let gridCellStroke = Color(.sRGB, white: 0.25, opacity: 1)
    static let gridFilledText = Color.black
    static let gridFilledFill = Color.white

    // MARK: - WCAG math

    /// WCAG 2.x relative luminance of an sRGB color (resolved via UIColor).
    ///
    /// Approximation: translucent fills (e.g. `wheelTileFill`, `gridUnfilledFill`)
    /// are alpha-composited over a white backdrop before computing luminance,
    /// since every fill in this palette sits on a light cell background or a
    /// light system material — that's the surface it's actually judged against
    /// on screen, not the color's raw (uncomposited) RGB.
    static func relativeLuminance(of color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func comp(_ c: CGFloat) -> Double { Double(c * a + (1 - a)) }
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(comp(r)) + 0.7152 * lin(comp(g)) + 0.0722 * lin(comp(b))
    }

    /// WCAG contrast ratio (1...21) between two opaque colors.
    static func contrastRatio(_ a: Color, _ b: Color) -> Double {
        let la = relativeLuminance(of: a), lb = relativeLuminance(of: b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
