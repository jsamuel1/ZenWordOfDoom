import SwiftUI

/// The payoff shown when a level is cleared: the score counts up, serenity earned
/// is celebrated, and a newly revealed Doom creature gets a fanfare line. Appears
/// over the held creature reveal during the completion beat, then the play screen
/// advances to the cut scene (spec workstream C — the missing dopamine beat).
struct ClearSummary: Equatable {
    let score: Int
    let serenityEarned: Int
    /// Non-nil only when this clear revealed a creature not seen before.
    let newCreatureID: String?
}

struct LevelClearView: View {
    let summary: ClearSummary
    let reducedMotion: Bool
    let onContinue: () -> Void

    @State private var shownScore = 0
    @State private var appeared = false

    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 44
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                Text("Level Cleared")
                    .font(.title2.weight(.bold))

                VStack(spacing: 2) {
                    Text("\(shownScore)")
                        .font(.system(size: scoreSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label("+\(summary.serenityEarned) serenity", systemImage: "leaf.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                if let creature = summary.newCreatureID {
                    VStack(spacing: 2) {
                        Text("NEW CREATURE")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.red)
                            .tracking(2)
                        Text(prettyName(creature))
                            .font(.title3.weight(.semibold))
                    }
                    .padding(.top, 2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
            .accessibilityFocused($focused)

            Button(action: onContinue) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 6)
            .accessibilityHint("On to the breath between levels")
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(radius: 20, y: 8)
        .scaleEffect(appeared || reducedMotion ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            animateIn()
            focused = true
        }
    }

    private func animateIn() {
        if reducedMotion {
            shownScore = summary.score
            appeared = true
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true }
        withAnimation(.easeOut(duration: 0.9)) { shownScore = summary.score }
    }

    private func prettyName(_ slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private var accessibilityText: String {
        var parts = ["Level cleared", "\(summary.score) points", "\(summary.serenityEarned) serenity"]
        if let c = summary.newCreatureID { parts.append("New creature: \(prettyName(c))") }
        return parts.joined(separator: ". ")
    }
}

#Preview {
    ZStack {
        Color.black
        LevelClearView(
            summary: ClearSummary(score: 486, serenityEarned: 15, newCreatureID: "bone-wraith"),
            reducedMotion: false,
            onContinue: {}
        )
    }
}
