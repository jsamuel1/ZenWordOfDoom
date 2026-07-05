import SwiftUI
import UIKit
import LevelGen

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
    /// Rendered as-is (no extra opacity) so the on-screen stroke is exactly
    /// the color the contrast test pins. Tuned to read as a subtle hairline:
    /// 3.71:1 against `gridUnfilledFill` — above the 3:1 UI-component floor,
    /// below the ~4:1 point where it starts reading as a heavy border.
    static let gridCellStroke = Color(.sRGB, white: 0.52, opacity: 1)
    static let gridFilledText = Color.black
    static let gridFilledFill = Color.white

    // MARK: - Increase Contrast variants (audit 6.2)

    /// Unfilled-cell fill used only when `colorSchemeContrast == .increased`
    /// (see `GridView`). Deliberately a separate constant from
    /// `gridUnfilledFill` — that one is pinned by `WCAGContrastTests` and
    /// must not change; this one is free to move independently.
    static let gridUnfilledFillIncreased = Color(.sRGB, white: 1, opacity: 0.92)
    /// Cell-stroke color used only when `colorSchemeContrast == .increased`
    /// (see `GridView`). Darker and more opaque than `gridCellStroke` for a
    /// stronger boundary; not pinned by `WCAGContrastTests`.
    static let gridCellStrokeIncreased = Color(.sRGB, white: 0.15, opacity: 0.85)

    // MARK: - Parchment chrome v2: picture-frame ring + mat fill (see ParchmentChrome.swift)
    //
    // v1 used a translucent scrim composited over a full-fill texture. v2
    // splits the frame (a thin decorative ring image) from the mat (a plain,
    // opaque, code-drawn fill) — so these are real fill colors, not a scrim,
    // and contrast is exact rather than alpha-composited-over-an-assumed-backdrop.

    static let parchmentMatZen = Color(.sRGB, red: 0.937, green: 0.910, blue: 0.839, opacity: 1)
    /// Slightly darker sand tone for the mat's subtle raked-line pattern —
    /// not pinned by contrast tests (never sits under text on its own).
    static let parchmentMatZenAccent = Color(.sRGB, red: 0.902, green: 0.867, blue: 0.776, opacity: 1)
    static let parchmentInkZen = Color(.sRGB, red: 0.169, green: 0.129, blue: 0.090, opacity: 1)

    static let parchmentMatDoom = Color(.sRGB, red: 0.173, green: 0.176, blue: 0.184, opacity: 1)
    /// Warm low-opacity glow overlaid near one edge of the doom mat — not
    /// pinned by contrast tests (a translucent accent, not the base fill).
    static let parchmentMatDoomGlow = Color(.sRGB, red: 1.0, green: 0.43, blue: 0.12, opacity: 0.16)
    static let parchmentInkDoom = Color(.sRGB, red: 0.953, green: 0.902, blue: 0.784, opacity: 1)

    /// Text/icon color to draw over the parchment mat for the given theme.
    static func parchmentInk(for theme: Theme) -> Color {
        theme == .doom ? parchmentInkDoom : parchmentInkZen
    }

    /// Base mat fill color for the given theme — the opaque backdrop text
    /// and icons sit on, sized to the button/pill's real content (no
    /// texture, no runtime compositing). See `ParchmentChrome.swift`.
    static func parchmentMat(for theme: Theme) -> Color {
        theme == .doom ? parchmentMatDoom : parchmentMatZen
    }

    // MARK: - WCAG math

    /// WCAG 2.x relative luminance of an sRGB color (resolved via UIColor).
    ///
    /// Approximation: translucent fills (e.g. `wheelTileFill`, `gridUnfilledFill`)
    /// are alpha-composited over a white backdrop before computing luminance —
    /// white is the *lightest* plausible backdrop for these fill-vs-dark-text
    /// pairs, i.e. the backdrop that maximizes the fill's luminance. The grid
    /// fills do sit on light cells/materials, but the wheel tile sits directly
    /// on scene art that can be dark; its pair was hand-checked over black as
    /// the worst case: white @ 0.9 over black gives ~13.2:1 against
    /// `wheelTileText`, still comfortably >= 4.5:1. (Compositing over white
    /// yields ~16.6:1, so the pinned test covers the lighter end and the
    /// hand-check covers the darker end.)
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
