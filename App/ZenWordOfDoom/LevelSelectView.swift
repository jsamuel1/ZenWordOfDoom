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
        let level = LevelLibrary.level(id: levelID)

        Button {
            router.push(.game(levelID: levelID))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: cleared ? "checkmark.seal.fill" : "circle")
                    .foregroundStyle(cleared ? Color.green : Color.secondary)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: levelID))
                        .font(.body.weight(.medium))
                    if let level {
                        Text(subtitle(for: level, progress: progress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
