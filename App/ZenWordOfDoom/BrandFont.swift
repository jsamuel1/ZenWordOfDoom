import SwiftUI

/// The game's two bundled brand faces — mirrors the type used on
/// zenofdoom.sauhsoj.wtf. Both are SIL Open Font License, registered via
/// `UIAppFonts` in Info.plist (`Fonts/Buda-Light.ttf`,
/// `Fonts/GrenzeGotisch-Bold.ttf`).
///
/// PostScript names (the `Font.custom` lookup key) differ from the display
/// family name — `Buda-Light`/`GrenzeGotisch-Bold` here, not `Buda`/
/// `Grenze Gotisch` — so this indirection also guards against a silent
/// fallback-to-system-font typo at every call site.
enum BrandFont {
    /// Buda (Light, its only published weight): condensed, East Asian
    /// calligraphic character, for Zen-themed type. Scales with Dynamic Type
    /// like the rest of the app's `@ScaledMetric` sizing — `size` is the
    /// value at the base content size, `relativeTo` anchors the scale curve.
    static func zen(size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom("Buda-Light", size: size, relativeTo: textStyle)
    }

    /// Grenze Gotisch (Bold): modern blackletter/gothic revival — the broken
    /// letterforms of traditional Fraktur with the ornamental swashes toned
    /// down for legibility — for Doom-themed type. Scales with Dynamic Type.
    static func doom(size: CGFloat, relativeTo textStyle: Font.TextStyle = .title) -> Font {
        .custom("GrenzeGotisch-Bold", size: size, relativeTo: textStyle)
    }
}
