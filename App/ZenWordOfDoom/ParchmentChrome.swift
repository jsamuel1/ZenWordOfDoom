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

/// Custom `ButtonStyle` rendering a stretchable parchment/oriental-frame
/// texture behind the button's label instead of the system `.bordered`/
/// `.borderedProminent` chrome. See
/// `docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md`.
struct ParchmentButtonStyle: ButtonStyle {
    let theme: Theme
    /// Only `.wide` or `.icon` — `.strip` backs `.parchmentReadout(theme:)`
    /// (non-button chrome) instead.
    let shape: ParchmentShape

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let insets = shape.capInsets
        configuration.label
            .foregroundStyle(AccessibilityPalette.parchmentInk(for: theme))
            .padding(.horizontal, shape == .icon ? 8 : 16)
            .padding(.vertical, shape == .icon ? 8 : 10)
            .frame(minWidth: 44, minHeight: 44)
            .background(
                ZStack {
                    Image(ParchmentShape.assetName(theme: theme, shape: shape))
                        .resizable(capInsets: insets, resizingMode: .stretch)
                        .accessibilityHidden(true)
                    AccessibilityPalette.parchmentScrim(for: theme)
                        .clipShape(RoundedRectangle(cornerRadius: shape == .icon ? 18 : 12, style: .continuous))
                        .padding(insets)
                }
            )
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("ParchmentButtonStyle") {
    VStack(spacing: 16) {
        Button("Play") {}
            .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))
        Button("Play") {}
            .buttonStyle(ParchmentButtonStyle(theme: .doom, shape: .wide))
        HStack(spacing: 16) {
            Button {} label: { Image(systemName: "lightbulb.fill") }
                .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .icon))
            Button {} label: { Image(systemName: "lightbulb.fill") }
                .buttonStyle(ParchmentButtonStyle(theme: .doom, shape: .icon))
        }
        Button("Disabled") {}
            .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))
            .disabled(true)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
