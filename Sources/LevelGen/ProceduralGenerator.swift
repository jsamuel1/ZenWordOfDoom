import Foundation
import GameCore

/// Assembles a deterministic `Level` from a seed: seeded wheel → themed
/// buildable word pool (from the provider) → crossword grid → seeded
/// scene/creature.
public struct ProceduralGenerator: Sendable {
    private let wordProvider: any ThemedWordProvider
    private let pools: ThemePools
    private let layout = CrosswordLayoutEngine()

    /// Maximum grid words to place.
    public static let maxSlots = 8

    /// Below this many interesting-word slots, fall back to the full pool so a
    /// word-poor wheel still gets a playable grid rather than a near-empty one.
    static let minInterestingSlots = 3

    public init(wordProvider: any ThemedWordProvider, pools: ThemePools) {
        self.wordProvider = wordProvider
        self.pools = pools
    }

    public func level(for seed: LevelSeed) async throws -> Level {
        let wheel = WheelPicker.wheel(theme: seed.theme, band: seed.band, index: seed.index)
        let pool = try await wordProvider.words(forWheel: wheel, theme: seed.theme, limit: Self.maxSlots * 3)
        let layoutSeed = WheelPicker.seed(theme: seed.theme, band: seed.band, index: seed.index) ^ 0x5EED

        // Build the grid from *interesting* words — on-theme (zen/doom) or common
        // dictionary words — so required answers are recognizable. Only fall back
        // to the full pool (which can include obscure corpus words like "LEPTA")
        // when the interesting set can't form a usable grid on this wheel.
        let lexicon = ThemeLexicon.shared
        let common = CommonWords.shared
        let interesting = pool.filter {
            lexicon.contains($0, theme: seed.theme) || common.contains($0)
        }
        var slots = layout.layout(words: interesting, maxSlots: Self.maxSlots, seed: layoutSeed)
        if slots.count < Self.minInterestingSlots {
            slots = layout.layout(words: pool, maxSlots: Self.maxSlots, seed: layoutSeed)
        }
        precondition(!slots.isEmpty, "ProceduralGenerator produced an empty grid for seed \(seed.id); word pool size \(pool.count)")
        let visual = SceneCreaturePicker(pools: pools).pick(theme: seed.theme, index: seed.index)
        return Level(
            id: seed.id,
            wheel: wheel,
            slots: slots,
            sceneID: visual.sceneID,
            creatureID: visual.creatureID
        )
    }
}
