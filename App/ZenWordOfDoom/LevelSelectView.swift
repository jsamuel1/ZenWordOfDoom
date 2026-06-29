import SwiftUI
import GameCore
import LevelKit

/// Lists every pack from `LevelLibrary` and the levels within, surfacing the
/// cleared state from the player's save. Tapping a level pushes into the game.
struct LevelSelectView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: GameStore

    private var packs: [PackData] { LevelLibrary.packs() }

    var body: some View {
        List {
            ForEach(packs, id: \.id) { pack in
                Section {
                    ForEach(pack.levelIDs, id: \.self) { levelID in
                        levelRow(levelID: levelID)
                    }
                } header: {
                    Text(pack.title)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Levels")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func levelRow(levelID: String) -> some View {
        let progress = store.state.progress[levelID]
        let cleared = progress?.cleared ?? false
        let unlocked = store.isUnlocked(levelID)
        let level = LevelLibrary.level(id: levelID)

        Button {
            // Locked levels can't be entered until the prior one is cleared.
            guard unlocked else { return }
            router.push(.game(levelID: levelID))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: statusIcon(cleared: cleared, unlocked: unlocked))
                    .foregroundStyle(cleared ? Color.green : Color.secondary)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: levelID))
                        .font(.body.weight(.medium))
                    if !unlocked {
                        Text("Locked — clear the previous level")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let level {
                        Text(subtitle(for: level, progress: progress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if unlocked {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .opacity(unlocked ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityHint(unlocked ? "" : "Locked")
    }

    private func statusIcon(cleared: Bool, unlocked: Bool) -> String {
        if cleared { return "checkmark.seal.fill" }
        return unlocked ? "circle" : "lock.fill"
    }

    private func displayName(for levelID: String) -> String {
        levelID
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func subtitle(for level: Level, progress: LevelProgress?) -> String {
        var parts = ["\(level.band.rawValue.capitalized) · \(level.wheel.size) letters"]
        if let progress, progress.cleared {
            parts.append("Best \(progress.bestScore)")
        }
        return parts.joined(separator: "  ")
    }
}
