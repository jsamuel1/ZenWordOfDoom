import SwiftUI
import LevelGen

/// The three parchment-frame texture shapes generated for this app's chrome
/// (see `docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md`).
/// `.wide` and `.icon` back `ParchmentButtonStyle`; `.strip` backs
/// `.parchmentReadout(theme:)`. Textures live in `Assets.xcassets/Frames/`.
enum ParchmentShape {
    case wide
    case icon
    case strip

    /// Fixed border margin (in the texture's own point space) that must not
    /// stretch — the torn-edge/corner-ornament detail lives here. Only the
    /// region inside these insets stretches when the view resizes.
    var capInsets: EdgeInsets {
        switch self {
        case .wide: EdgeInsets(top: 70, leading: 110, bottom: 70, trailing: 110)
        case .icon: EdgeInsets(top: 90, leading: 90, bottom: 90, trailing: 90)
        case .strip: EdgeInsets(top: 35, leading: 100, bottom: 35, trailing: 100)
        }
    }

    static func assetName(theme: Theme, shape: ParchmentShape) -> String {
        let themeName = theme == .doom ? "doom" : "zen"
        let shapeName: String
        switch shape {
        case .wide: shapeName = "button"
        case .icon: shapeName = "icon"
        case .strip: shapeName = "strip"
        }
        return "frame-\(themeName)-\(shapeName)"
    }
}
