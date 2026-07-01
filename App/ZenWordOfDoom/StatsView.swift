import SwiftUI
import GameCore

/// Lifetime statistics gathered across all play (spec workstream C). Read-only;
/// reflects `GameStore.state.stats` plus derived values.
struct StatsView: View {
    @EnvironmentObject private var store: GameStore

    private var stats: GameStats { store.state.stats }

    var body: some View {
        List {
            Section("Streak") {
                row("Current daily streak", "\(stats.currentStreak)", "flame.fill")
                row("Best streak", "\(stats.bestStreak)", "trophy.fill")
            }
            Section("Words") {
                row("Words found", "\(stats.totalWordsFound)", "text.word.spacing")
                row("Bonus words", "\(stats.totalBonusWords)", "sparkles")
                row("Pangrams", "\(stats.pangrams)", "star.circle.fill")
                row("Longest word", stats.longestWord.isEmpty ? "—" : stats.longestWord, "ruler")
            }
            Section("Progress") {
                row("Levels cleared", "\(stats.levelsCleared)", "checkmark.seal.fill")
                row("Creatures revealed", "\(stats.creaturesRevealed)", "pawprint.fill")
                row("Serenity", "\(store.state.serenity)", "leaf.fill")
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String, _ systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
