import SwiftUI
import GameCore
import LevelGen

/// Lists the procedural level sequence from `LevelService` in themed packs,
/// surfacing cleared/locked state from the player's save. Tapping a level
/// pushes into the game.
struct LevelSelectView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var levelService: LevelService

    /// Levels to show: every unlocked level (order 0 is always unlocked), plus a
    /// few locked previews. Starts at order 0.
    private var visibleIDs: [String] {
        var furthest = 0
        while furthest < 100_000, store.isUnlocked(levelService.id(atOrder: furthest)) {
            furthest += 1
        }
        return levelService.ids(through: furthest + 3)
    }

    /// `visibleIDs` chunked into packs of 10, titled by the chunk's theme · band.
    private var sections: [(title: String, ids: [String])] {
        let ids = visibleIDs
        var result: [(String, [String])] = []
        var i = 0
        while i < ids.count {
            let chunk = Array(ids[i..<min(i + 10, ids.count)])
            if let first = chunk.first {
                let theme = levelService.theme(forID: first).rawValue.capitalized
                let band = DifficultyBand(wheelSize: levelService.wheelSize(forID: first))
                    .rawValue.capitalized
                result.append(("\(theme) · \(band)", chunk))
            }
            i += 10
        }
        return result
    }

    var body: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.ids, id: \.self) { levelID in
                        levelRow(levelID: levelID)
                    }
                } header: {
                    Text(section.title)
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
                    } else {
                        Text(subtitle(for: levelID, progress: progress))
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

    private func subtitle(for levelID: String, progress: LevelProgress?) -> String {
        let n = levelService.wheelSize(forID: levelID)
        let band = DifficultyBand(wheelSize: n).rawValue.capitalized
        var parts = ["\(band) · \(n) letters"]
        if let progress, progress.cleared {
            parts.append("Best \(progress.bestScore)")
        }
        return parts.joined(separator: "  ")
    }
}
