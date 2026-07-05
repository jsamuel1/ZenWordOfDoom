import SwiftUI
import LevelGen

/// The play-screen heads-up display: score, serenity, and a hint button.
/// Pure view driven by value inputs and closures; it holds no reference to
/// the game view model. The doom timer is a separate `DoomTimerView`, shown
/// above this bar rather than inside it — see that type's doc comment. The
/// mic toggle lives in `GameContainerView`'s bottom control panel, not here.
struct HUDView: View {
    let score: Int
    let serenity: Int
    let hintCost: Int
    /// Whether this level format has anything for a hint to reveal (hides the
    /// button when false — e.g. `.pangramHunt` levels have no grid slots).
    let hintsEnabled: Bool
    let theme: Theme

    let onHint: () -> Void

    private var canAffordHint: Bool { serenity >= hintCost }

    var body: some View {
        HStack(spacing: 12) {
            stat(title: "Score", value: "\(score)", systemImage: "star.fill")
            stat(title: "Serenity", value: "\(serenity)", systemImage: "leaf.fill")

            Spacer(minLength: 0)

            if hintsEnabled {
                hintButton
            }
        }
    }

    private func stat(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption2)
            }
        }
        .parchmentReadout(theme: theme)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private var hintButton: some View {
        Button(action: onHint) {
            Label("Hint", systemImage: "lightbulb.fill")
                .labelStyle(.iconOnly)
                .font(.title3)
        }
        .buttonStyle(ParchmentButtonStyle(theme: theme, shape: .icon))
        .disabled(!canAffordHint)
        .accessibilityLabel("Reveal a hint for \(hintCost) serenity")
        .accessibilityHint(canAffordHint ? "" : "Not enough serenity")
    }

}

/// Standalone doom-timer readout. Shown between the navigation title and
/// `HUDView` — rather than inside the HUD's own stat row — so a doom level's
/// timer doesn't compete with Score/Serenity/hint for horizontal space
/// in that bar; zen levels simply omit this view.
struct DoomTimerView: View {
    let timeRemaining: TimeInterval
    /// Current doom bonus tier (4x/3x/2x, 1 after expiry). Shown as a badge
    /// beside the countdown so the player knows what beating the clock buys.
    let multiplier: Int
    let theme: Theme

    var body: some View {
        let secs = max(0, Int(timeRemaining.rounded()))
        let mm = secs / 60
        let ss = secs % 60
        let urgent = timeRemaining <= 15
        // Color applied directly on each leaf, not on the HStack: a
        // container-level .foregroundStyle set here would sit closer to
        // these Image/Text leaves than parchmentReadout's own internal ink
        // color (applied further out, wrapping this whole HStack), so it
        // would always win — silently discarding the theme's ink color and
        // rendering as near-black on the dark Doom scrim. Setting the color
        // on the leaves themselves is unambiguously the closest/most
        // specific setting, so it's the one that actually applies.
        let timerColor = urgent ? Color.red : AccessibilityPalette.parchmentInk(for: theme)
        HStack(spacing: 4) {
            Image(systemName: "hourglass")
                .font(.caption)
                .foregroundStyle(timerColor)
            Text(String(format: "%d:%02d", mm, ss))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(timerColor)
            if multiplier > 1 {
                Text("×\(multiplier)")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(timerColor)
            }
        }
        .parchmentReadout(theme: theme)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Time remaining \(mm) minutes \(ss) seconds"
                + (multiplier > 1 ? ", scoring \(multiplier) times points" : "")
        )
    }
}

#Preview {
    VStack {
        DoomTimerView(timeRemaining: 92, multiplier: 3, theme: .zen)
        HUDView(
            score: 320,
            serenity: 25,
            hintCost: 5,
            hintsEnabled: true,
            theme: .zen,
            onHint: {}
        )
        HUDView(
            score: 0,
            serenity: 2,
            hintCost: 5,
            hintsEnabled: true,
            theme: .zen,
            onHint: {}
        )
    }
    .padding()
    .background(Color.black)
}
