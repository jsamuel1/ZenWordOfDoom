import SwiftUI
import LevelGen

/// The three picture-frame texture shapes generated for this app's chrome
/// (see `docs/superpowers/specs/2026-07-05-parchment-frame-v2-picture-frame-design.md`).
/// `.wide` and `.icon` back `ParchmentButtonStyle`; `.strip` backs
/// `.parchmentReadout(theme:)`. Textures live in `Assets.xcassets/Frames/`.
///
/// v2 design: each texture is a THIN RING with a fully transparent center —
/// unlike v1, which tried to make one texture serve as both the decorative
/// border AND the full background fill via `capInsets` stretching. That dual
/// duty is what caused v1's whole run of bugs (oversized buttons overlapping
/// neighbors, text washed out under a mis-layered scrim, a border that only
/// rendered on one edge) — the capInset needed to protect the ornament and
/// the capInset needed to keep the button small were in direct conflict.
/// Splitting frame (thin ring, this file's `Image` background) from mat (a
/// plain code-drawn fill, `ParchmentMatView` below) removes that conflict
/// structurally: the ring's transparent center means its capInsets never
/// need to be large, and the mat never needs `capInsets`/stretching at all.
enum ParchmentShape {
    case wide
    case icon
    case strip

    /// Fixed border margin, in POINTS — the ring art lives here. Only the
    /// (fully transparent) center stretches, so unlike v1 there's no visual
    /// risk in that region even if it stretches oddly.
    ///
    /// These are the real ring thickness measured from each PNG's alpha
    /// channel, divided by 3 (the textures are marked `scale: 3x` in their
    /// Contents.json — see `generate-parchment-frames.sh` — because they're
    /// generated at print-quality canvas sizes like 900x300 but rendered at
    /// a ~50pt-tall button; without the 3x marking, capInsets would need to
    /// describe a 900x300-POINT image, forcing sums far bigger than any real
    /// button and reintroducing v1's oversizing bug). Doom's rings measured
    /// thicker than Zen's for `.wide`/`.strip`; each value here is the safe
    /// (larger, doom) side so neither theme's ring gets cropped into the
    /// stretch region — the unused margin on Zen's side is still fully
    /// transparent there, so it's invisible either way.
    var capInsets: EdgeInsets {
        switch self {
        case .wide: EdgeInsets(top: 17, leading: 25, bottom: 15, trailing: 25)
        case .icon: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        case .strip: EdgeInsets(top: 13, leading: 13, bottom: 13, trailing: 13)
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

/// The plain, opaque fill behind a button/readout's text — replaces v1's
/// translucent scrim entirely. Themed with a cheap, subtle decorative
/// pattern (matches the approved mockup): a raked-sand diagonal line pattern
/// for Zen, a faint warm ember glow for Doom. Both layer on top of a fixed,
/// WCAG-pinned base color (`AccessibilityPalette.parchmentMat(for:)`) — the
/// pattern accents are never relied on for contrast, only the base fill is.
private struct ParchmentMatView: View {
    let theme: Theme

    var body: some View {
        ZStack {
            AccessibilityPalette.parchmentMat(for: theme)
            switch theme {
            case .zen:
                RakedLinesView()
                    .stroke(AccessibilityPalette.parchmentMatZenAccent, lineWidth: 1)
                    .opacity(0.6)
            case .doom:
                RadialGradient(
                    colors: [AccessibilityPalette.parchmentMatDoomGlow, .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 90
                )
            }
        }
    }
}

/// A handful of parallel diagonal lines, evoking a raked zen-garden sand
/// pattern. Pure geometry (no image), cheap to draw, scales with the view.
private struct RakedLinesView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 8
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += spacing
        }
        return path
    }
}

/// Custom `ButtonStyle` rendering a thin picture-frame ring behind the
/// button's label instead of the system `.bordered`/`.borderedProminent`
/// chrome. See
/// `docs/superpowers/specs/2026-07-05-parchment-frame-v2-picture-frame-design.md`.
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
            .padding(.horizontal, shape == .icon ? 10 : 18)
            .padding(.vertical, shape == .icon ? 10 : 12)
            .frame(minWidth: shape == .icon ? 52 : 44, minHeight: shape == .icon ? 52 : 44)
            .background {
                // Frame ring in FRONT of the mat (both the same size as this
                // content box): the ring's transparent center lets the mat
                // show through exactly where there's no rock art, and its
                // opaque outer ring paints over the mat's own edge —
                // together they read as a mat sitting inside a frame,
                // without needing the mat and frame to be independently
                // sized/inset from each other.
                Image(ParchmentShape.assetName(theme: theme, shape: shape))
                    .resizable(capInsets: insets, resizingMode: .stretch)
                    .accessibilityHidden(true)
            }
            .background {
                ParchmentMatView(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: shape == .icon ? 14 : 8, style: .continuous))
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
            .padding(.vertical, 7)
            .background {
                Image(ParchmentShape.assetName(theme: theme, shape: .strip))
                    .resizable(capInsets: insets, resizingMode: .stretch)
                    .accessibilityHidden(true)
            }
            .background {
                ParchmentMatView(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
