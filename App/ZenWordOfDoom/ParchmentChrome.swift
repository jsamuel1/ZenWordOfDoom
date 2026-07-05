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

    /// Where the opaque mat fill stops, measured in from the same edges as
    /// `capInsets`. Three-quarters of the ring thickness: the mat's edge
    /// tucks under only the stones' inner quarter, so the backdrop art shows
    /// through the ring's transparent pixels — outside the stone silhouette
    /// AND in the gaps between stones — instead of a mat-colored rounded
    /// rectangle filling the ring band behind the rocks.
    var matInsets: EdgeInsets {
        let cap = capInsets
        return EdgeInsets(
            top: cap.top * 0.75, leading: cap.leading * 0.75,
            bottom: cap.bottom * 0.75, trailing: cap.trailing * 0.75
        )
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
            // .wide's padding must clear its ring band (capInsets: 25pt
            // leading/trailing, ~17pt top) with breathing room, or
            // leading-aligned label text starts on top of the stones.
            .padding(.horizontal, shape == .icon ? 10 : 26)
            .padding(.vertical, shape == .icon ? 10 : 18)
            .frame(minWidth: shape == .icon ? 52 : 44, minHeight: shape == .icon ? 52 : 44)
            .background {
                // Frame ring in FRONT of the mat: the ring's transparent
                // center lets the mat show through exactly where there's no
                // rock art, while the mat stops at `matInsets` — its edge
                // tucked under the stones — so everything outside/between
                // the stones stays see-through instead of showing a
                // mat-colored rounded rectangle behind the ring.
                Image(ParchmentShape.assetName(theme: theme, shape: shape))
                    .resizable(capInsets: insets, resizingMode: .stretch)
                    .accessibilityHidden(true)
            }
            .background {
                ParchmentMatView(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: shape == .icon ? 14 : 8, style: .continuous))
                    .padding(shape.matInsets)
            }
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Plain-row button style for buttons that sit INSIDE a `.parchmentPanel` —
/// the panel supplies the (single, shared) frame ring and mat, so rows draw
/// no chrome of their own beyond the themed ink color and press feedback.
struct ParchmentRowButtonStyle: ButtonStyle {
    let theme: Theme

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AccessibilityPalette.parchmentInk(for: theme))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct ParchmentPanelModifier: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        let insets = ParchmentShape.wide.capInsets
        content
            // Push the content clear of the ring band so rows never overlap
            // the stones; the transparent center stretches to fit whatever
            // height the stacked rows need.
            .padding(EdgeInsets(
                top: insets.top + 4, leading: insets.leading + 4,
                bottom: insets.bottom + 4, trailing: insets.trailing + 4
            ))
            .background {
                Image(ParchmentShape.assetName(theme: theme, shape: .wide))
                    .resizable(capInsets: insets, resizingMode: .stretch)
                    .accessibilityHidden(true)
            }
            .background {
                ParchmentMatView(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(ParchmentShape.wide.matInsets)
            }
    }
}

extension View {
    /// One shared parchment piece (frame ring + mat) around a whole group of
    /// content — e.g. the main menu's stacked navigation rows — instead of
    /// each child carrying its own `ParchmentButtonStyle` border. Pair with
    /// `ParchmentRowButtonStyle` for the buttons inside.
    func parchmentPanel(theme: Theme) -> some View {
        modifier(ParchmentPanelModifier(theme: theme))
    }
}

private struct ParchmentReadoutModifier: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        let insets = ParchmentShape.strip.capInsets
        content
            .foregroundStyle(AccessibilityPalette.parchmentInk(for: theme))
            .padding(.horizontal, 14)
            // Vertical padding must stay >= .strip's matInsets (9.75pt) so
            // text never pokes past the mat's edge onto the transparent
            // stone gaps, where contrast is unpinned.
            .padding(.vertical, 10)
            .background {
                Image(ParchmentShape.assetName(theme: theme, shape: .strip))
                    .resizable(capInsets: insets, resizingMode: .stretch)
                    .accessibilityHidden(true)
            }
            .background {
                ParchmentMatView(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(ParchmentShape.strip.matInsets)
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
        VStack(spacing: 0) {
            Button("Select Level") {}
                .buttonStyle(ParchmentRowButtonStyle(theme: .zen))
            Rectangle()
                .fill(AccessibilityPalette.parchmentInk(for: .zen).opacity(0.15))
                .frame(height: 1)
            Button("Settings") {}
                .buttonStyle(ParchmentRowButtonStyle(theme: .zen))
        }
        .parchmentPanel(theme: .zen)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
