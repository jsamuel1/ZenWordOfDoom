import SwiftUI

/// The play-screen heads-up display: score, serenity, a hint button, an optional
/// doom timer, and a mic toggle. Pure view driven by value inputs and closures;
/// it holds no reference to the game view model.
struct HUDView: View {
    let score: Int
    let serenity: Int
    let hintCost: Int
    /// Seconds remaining in doom mode, or `nil` in zen mode (timer hidden).
    let timeRemaining: TimeInterval?
    /// Whether the mic is currently listening (toggles the button appearance).
    let isListening: Bool
    /// Whether voice input is available/enabled at all (hides the mic when false).
    let voiceEnabled: Bool

    let onHint: () -> Void
    let onMicStart: () -> Void
    let onMicStop: () -> Void

    private var canAffordHint: Bool { serenity >= hintCost }

    var body: some View {
        HStack(spacing: 12) {
            stat(title: "Score", value: "\(score)", systemImage: "star.fill")
            stat(title: "Serenity", value: "\(serenity)", systemImage: "leaf.fill")

            if let timeRemaining {
                timerView(timeRemaining)
            }

            Spacer(minLength: 0)

            hintButton
            if voiceEnabled {
                micButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func stat(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private func timerView(_ remaining: TimeInterval) -> some View {
        let secs = max(0, Int(remaining.rounded()))
        let mm = secs / 60
        let ss = secs % 60
        let urgent = remaining <= 15
        return HStack(spacing: 4) {
            Image(systemName: "hourglass")
                .font(.caption)
            Text(String(format: "%d:%02d", mm, ss))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(urgent ? Color.red : Color.primary)
        .accessibilityLabel("Time remaining \(mm) minutes \(ss) seconds")
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
                .symbolEffect(.pulse, isActive: isListening)
        }
        .accessibilityLabel(isListening ? "Stop listening" : "Speak a word")
    }
}

#Preview {
    VStack {
        HUDView(
            score: 320,
            serenity: 25,
            hintCost: 5,
            timeRemaining: 92,
            isListening: false,
            voiceEnabled: true,
            onHint: {},
            onMicStart: {},
            onMicStop: {}
        )
        HUDView(
            score: 0,
            serenity: 2,
            hintCost: 5,
            timeRemaining: nil,
            isListening: true,
            voiceEnabled: true,
            onHint: {},
            onMicStart: {},
            onMicStop: {}
        )
    }
    .padding()
    .background(Color.black)
}
