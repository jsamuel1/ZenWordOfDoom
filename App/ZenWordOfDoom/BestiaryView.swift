import SwiftUI
import GameCore
import LevelGen

/// The collection of Doom creatures. Every creature that appears across the
/// level library is listed; those the player has revealed show their details,
/// the rest are silhouetted as "not yet revealed".
struct BestiaryView: View {
    @EnvironmentObject private var store: GameStore

    /// The doom creatures the player can encounter, in stable order.
    private var allCreatureIDs: [String] {
        (ThemePools.zenDoom.creatures[.doom] ?? []).sorted()
    }

    var body: some View {
        List {
            Section {
                ForEach(allCreatureIDs, id: \.self) { creatureID in
                    row(for: creatureID)
                }
            } header: {
                let revealed = store.state.bestiary.keys.filter { allCreatureIDs.contains($0) }.count
                Text("\(revealed) of \(allCreatureIDs.count) revealed")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Bestiary")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(for creatureID: String) -> some View {
        let entry = store.state.bestiary[creatureID]
        let revealed = entry != nil

        HStack(spacing: 12) {
            Image(systemName: revealed ? "pawprint.fill" : "questionmark.circle")
                .imageScale(.large)
                .foregroundStyle(revealed ? Color.red.opacity(0.8) : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(revealed ? displayName(for: creatureID) : "Not yet revealed")
                    .font(.body.weight(.medium))
                    .redacted(reason: revealed ? [] : .placeholder)
                if let entry {
                    Text("First seen in \(displayName(for: entry.firstRevealedLevelID))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func displayName(for id: String) -> String {
        id
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
