import SwiftUI

/// The play-screen heads-up display: score, serenity, a hint button, and a mic
/// toggle. Pure view driven by value inputs and closures; it holds no
/// reference to the game view model. The doom timer is a separate
/// `DoomTimerView`, shown above this bar rather than inside it — see that
/// type's doc comment.
struct HUDView: View {
    let score: Int
    /// True when the doom timer expired and the level's points are forfeit;
    /// the score renders as an em dash instead of a number.
    let scoreVoided: Bool
    let serenity: Int
    let hintCost: Int
    /// Whether the mic is currently listening (toggles the button appearance).
    let isListening: Bool
    /// Whether voice input is available/enabled at all (hides the mic when false).
    let voiceEnabled: Bool
    /// Whether this level format has anything for a hint to reveal (hides the
    /// button when false — e.g. `.pangramHunt` levels have no grid slots).
    let hintsEnabled: Bool

    let onHint: () -> Void
    let onMicStart: () -> Void
    let onMicStop: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    /// Reduce Motion (audit 5.3): the mic's pulse symbol effect is purely
    /// decorative, so it's suppressed rather than replaced.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canAffordHint: Bool { serenity >= hintCost }

    /// Increase Contrast (audit 6.2): the caption labels default to
    /// `.secondary`, which can thin out over busy scene art; bump to
    /// `.primary` when the setting is on.
    private var labelStyle: Color { contrast == .increased ? .primary : .secondary }

    var body: some View {
        HStack(spacing: 12) {
            stat(title: "Score", value: scoreVoided ? "\u{2014}" : "\(score)", systemImage: "star.fill")
            stat(title: "Serenity", value: "\(serenity)", systemImage: "leaf.fill")

            Spacer(minLength: 0)

            if hintsEnabled {
                hintButton
            }
            if voiceEnabled {
                micButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // Constant dark backing sits beneath the material (audit 3.5) so
        // `.secondary` labels hold contrast over bright/light scene art;
        // `a11yCardBackground` layers on top and goes opaque under Reduce
        // Transparency.
        .a11yCardBackground(cornerRadius: .infinity)
        .background(Capsule().fill(Color.black.opacity(0.25)))
    }

    private func stat(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(labelStyle)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(labelStyle)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private var hintButton: some View {
        Button(action: onHint) {
            Label("Hint", systemImage: "lightbulb.fill")
                .labelStyle(.iconOnly)
                .font(.title3)
                .padding(8)
                .background(
                    Circle().fill(canAffordHint
                        ? Color.accentColor.opacity(0.85)
                        : Color.gray.opacity(0.4))
                )
                .foregroundStyle(.white)
                // 44pt touch-target floor (audit 4.1): enlarges the tappable
                // area only — the visible circle above stays its original size.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(!canAffordHint)
        .accessibilityLabel("Reveal a hint for \(hintCost) serenity")
        .accessibilityHint(canAffordHint ? "" : "Not enough serenity")
    }

    private var micButton: some View {
        Button(action: { isListening ? onMicStop() : onMicStart() }) {
            Image(systemName: isListening ? "mic.fill" : "mic")
                .font(.title3)
                .padding(8)
                .background(
                    Circle().fill(isListening
                        ? Color.red.opacity(0.85)
                        : Color.secondary.opacity(0.25))
                )
                .foregroundStyle(isListening ? .white : .primary)
                .symbolEffect(.pulse, isActive: isListening && !reduceMotion)
                // 44pt touch-target floor (audit 4.1): enlarges the tappable
                // area only — the visible circle above stays its original size.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(isListening ? "Stop listening" : "Speak a word")
    }
}

/// Standalone doom-timer readout. Shown between the navigation title and
/// `HUDView` — rather than inside the HUD's own stat row — so a doom level's
/// timer doesn't compete with Score/Serenity/hint/mic for horizontal space
/// in that bar; zen levels simply omit this view.
struct DoomTimerView: View {
    let timeRemaining: TimeInterval

    var body: some View {
        let secs = max(0, Int(timeRemaining.rounded()))
        let mm = secs / 60
        let ss = secs % 60
        let urgent = timeRemaining <= 15
        HStack(spacing: 4) {
            Image(systemName: "hourglass")
                .font(.caption)
            Text(String(format: "%d:%02d", mm, ss))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(urgent ? Color.red : Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .a11yCardBackground(cornerRadius: .infinity)
        .background(Capsule().fill(Color.black.opacity(0.25)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time remaining \(mm) minutes \(ss) seconds")
    }
}

#Preview {
    VStack {
        DoomTimerView(timeRemaining: 92)
        HUDView(
            score: 320,
            scoreVoided: false,
            serenity: 25,
            hintCost: 5,
            isListening: false,
            voiceEnabled: true,
            hintsEnabled: true,
            onHint: {},
            onMicStart: {},
            onMicStop: {}
        )
        HUDView(
            score: 0,
            scoreVoided: true,
            serenity: 2,
            hintCost: 5,
            isListening: true,
            voiceEnabled: true,
            hintsEnabled: true,
            onHint: {},
            onMicStart: {},
            onMicStop: {}
        )
    }
    .padding()
    .background(Color.black)
}
