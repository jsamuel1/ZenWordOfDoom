import SwiftUI
import LevelGen

/// Parchment chrome v3: a plain themed mat (parchment fill with a subtle
/// decorative pattern) framed by a THIN TWO-TONE ACCENT OUTLINE — an outer
/// stroke in the theme's accent (moss green for Zen, deep ember for Doom)
/// with a lighter companion inlay line just inside it. Entirely code-drawn:
/// v2's generated stone-ring textures (and their capInset stretching, mat
/// tuck-under insets, and per-asset regeneration script) are gone.
///
/// The three shapes only differ in corner radius and content padding now.
/// `.wide` and `.icon` back `ParchmentButtonStyle`; `.strip` backs
/// `.parchmentReadout(theme:)`; `.parchmentPanel(theme:)` wraps grouped
/// content (menu rows, the play-screen control bar) in one shared piece.
enum ParchmentShape {
    case wide
    case icon
    case strip

    var cornerRadius: CGFloat {
        switch self {
        case .wide: 12
        case .icon: 14
        case .strip: 10
        }
    }
}

/// The two-tone outline: a 1.5pt outer stroke in the theme accent and a 1pt
/// lighter inlay line inset just inside it — reads as fine inlay work rather
/// than a border. Decorative only (never under text), so the accent colors
/// aren't contrast-pinned.
private struct ParchmentBorder: View {
    let theme: Theme
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(AccessibilityPalette.parchmentAccent(for: theme), lineWidth: 1.5)
            .overlay(
                RoundedRectangle(cornerRadius: max(cornerRadius - 3, 2), style: .continuous)
                    .strokeBorder(AccessibilityPalette.parchmentAccentSoft(for: theme), lineWidth: 1)
                    .padding(3)
            )
            .allowsHitTesting(false)
    }
}

/// The plain, opaque fill behind a button/readout's text. Themed with a
/// cheap, subtle decorative pattern: a raked-sand diagonal line pattern for
/// Zen, a faint warm ember glow for Doom. Both layer on top of a fixed,
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

/// Mat + two-tone outline behind any content box — the one place the v3
/// chrome layers are composed, shared by buttons, readouts, and panels.
private struct ParchmentSurface: ViewModifier {
    let theme: Theme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ParchmentMatView(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                ParchmentBorder(theme: theme, cornerRadius: cornerRadius)
            }
    }
}

/// Custom `ButtonStyle` rendering the parchment mat + thin two-tone accent
/// outline behind the button's label instead of system chrome.
struct ParchmentButtonStyle: ButtonStyle {
    let theme: Theme
    /// Only `.wide` or `.icon` — `.strip` backs `.parchmentReadout(theme:)`
    /// (non-button chrome) instead.
    let shape: ParchmentShape

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AccessibilityPalette.parchmentInk(for: theme))
            .padding(.horizontal, shape == .icon ? 10 : 16)
            .padding(.vertical, shape == .icon ? 10 : 12)
            .frame(minWidth: shape == .icon ? 52 : 44, minHeight: shape == .icon ? 52 : 44)
            .modifier(ParchmentSurface(theme: theme, cornerRadius: shape.cornerRadius))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Plain-row button style for buttons that sit INSIDE a `.parchmentPanel` —
/// the panel supplies the (single, shared) mat and outline, so rows draw no
/// chrome of their own beyond the themed ink color and press feedback.
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
        content
            .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .modifier(ParchmentSurface(theme: theme, cornerRadius: ParchmentShape.wide.cornerRadius))
    }
}

extension View {
    /// One shared parchment piece (mat + two-tone outline) around a whole
    /// group of content — e.g. the main menu's stacked navigation rows —
    /// instead of each child carrying its own `ParchmentButtonStyle` border.
    /// Pair with `ParchmentRowButtonStyle` for the buttons inside.
    func parchmentPanel(theme: Theme) -> some View {
        modifier(ParchmentPanelModifier(theme: theme))
    }
}

private struct ParchmentReadoutModifier: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(AccessibilityPalette.parchmentInk(for: theme))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .modifier(ParchmentSurface(theme: theme, cornerRadius: ParchmentShape.strip.cornerRadius))
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
        HStack(spacing: 4) {
            Image(systemName: "hourglass").font(.caption)
            Text("2:21 ×4").font(.subheadline.weight(.bold))
        }
        .parchmentReadout(theme: .doom)
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
