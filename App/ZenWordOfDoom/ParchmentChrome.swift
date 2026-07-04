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
    ///
    /// `Image.resizable(capInsets:)` enforces a HARD MINIMUM size equal to
    /// the sum of the insets on each axis — below that, it refuses to shrink
    /// further, no matter what size its container proposes. `.background()`
    /// never lets a background's size affect the primary view it's attached
    /// to, so when these values were much larger (70/110pt, implying a
    /// 140x220pt floor), a single-line button whose real content was only
    /// ~55pt tall still got a ~140pt-tall background rendered underneath —
    /// visually overflowing into the next control while the VStack kept
    /// spacing everything based on the button's true (small) height. Every
    /// value here must stay comfortably under 44 (the accessibility minimum
    /// touch target every shape already enforces via
    /// `.frame(minWidth: 44, minHeight: 44)`), so the enforced floor can
    /// never exceed a button's real minimum size.
    var capInsets: EdgeInsets {
        switch self {
        case .wide: EdgeInsets(top: 16, leading: 40, bottom: 16, trailing: 40)
        case .icon: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        case .strip: EdgeInsets(top: 12, leading: 30, bottom: 12, trailing: 30)
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
            .background {
                // Scrim and image are ZStack siblings INSIDE .background — both
                // must render behind the label. An `.overlay` here instead
                // would paint on top of everything including the text (overlay
                // always draws in front of the view it modifies), washing out
                // dark ink under the translucent scrim.
                ZStack {
                    Image(ParchmentShape.assetName(theme: theme, shape: shape))
                        .resizable(capInsets: insets, resizingMode: .stretch)
                        .accessibilityHidden(true)
                    AccessibilityPalette.parchmentScrim(for: theme)
                        .clipShape(RoundedRectangle(cornerRadius: shape == .icon ? 18 : 12, style: .continuous))
                        .padding(insets)
                }
            }
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct ParchmentReadoutModifier: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        let insets = ParchmentShape.strip.capInsets
        content
            .foregroundStyle(AccessibilityPalette.parchmentInk(for: theme))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    Image(ParchmentShape.assetName(theme: theme, shape: .strip))
                        .resizable(capInsets: insets, resizingMode: .stretch)
                        .accessibilityHidden(true)
                    AccessibilityPalette.parchmentScrim(for: theme)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(insets)
                }
            }
    }
}

extension View {
    /// Non-button parchment chrome (HUD pills, doom timer, word ribbon,
    /// found-words tags) — the readout equivalent of `ParchmentButtonStyle`.
    /// Stands in for `.a11yCardBackground(...)` only at these specific call
    /// sites; `a11yCardBackground` itself is untouched.
    func parchmentReadout(theme: Theme) -> some View {
        modifier(ParchmentReadoutModifier(theme: theme))
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
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.caption)
            Text("320").font(.subheadline.weight(.bold))
        }
        .parchmentReadout(theme: .zen)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
