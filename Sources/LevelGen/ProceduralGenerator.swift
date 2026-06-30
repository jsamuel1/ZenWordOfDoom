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

    public init(wordProvider: any ThemedWordProvider, pools: ThemePools) {
        self.wordProvider = wordProvider
        self.pools = pools
    }

    public func level(for seed: LevelSeed) async throws -> Level {
        let wheel = WheelPicker.wheel(theme: seed.theme, band: seed.band, index: seed.index)
        let pool = try await wordProvider.words(forWheel: wheel, theme: seed.theme, limit: Self.maxSlots * 3)
        let layoutSeed = WheelPicker.seed(theme: seed.theme, band: seed.band, index: seed.index) ^ 0x5EED
        let slots = layout.layout(words: pool, maxSlots: Self.maxSlots, seed: layoutSeed)
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
