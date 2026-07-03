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
        // `seed.index` is the global play order (see ProceduralLevelLibrary), so
        // it drives pack/capstone identity.
        let order = seed.index

        // Scene first, then a scene-coupled wheel, so the words the player spells
        // relate to the scene being revealed (spec workstream F).
        let visual = SceneCreaturePicker(pools: pools).pick(theme: seed.theme, index: seed.index)
        let wheel = try WheelPicker.wheel(sceneID: visual.sceneID, theme: seed.theme,
                                          band: seed.band, index: seed.index)

        // Pack capstone => Pangram-Hunt boss (spec workstream G). The scene-coupled
        // wheel is a real N-letter word, so a pangram (that word) always exists.
        let packSize = ProceduralLevelLibrary.standard.packSize
        if PackCatalog.standard.isCapstone(order: order, packSize: packSize) {
            let signature = PackCatalog.standard.signatureCreatureID(
                forOrder: order, packSize: packSize, theme: seed.theme, pools: pools)
            return Level(
                id: seed.id,
                wheel: wheel,
                slots: [],
                sceneID: visual.sceneID,
                creatureID: signature.isEmpty ? visual.creatureID : signature,
                format: .pangramHunt(target: PackCatalog.pangramTarget(for: seed.band))
            )
        }

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
        guard !slots.isEmpty else {
            throw LevelGenError.emptyGrid(seedID: seed.id, poolSize: pool.count)
        }
        return Level(
            id: seed.id,
            wheel: wheel,
            slots: slots,
            sceneID: visual.sceneID,
            creatureID: visual.creatureID
        )
    }

    /// The Word-of-the-Day bonus level: always a grid-less Pangram-Hunt whose
    /// wheel is the curated word's own letters (so it's always a completable
    /// pangram), with the word's own illustration slug as the scene (see
    /// `WordOfTheDayImages`) and a creature still drawn from the theme's
    /// normal pool. Synchronous — like pack-capstone Pangram-Hunt levels,
    /// this never touches the async `wordProvider`.
    ///
    /// The target word-count is derived from the word's *actual* length
    /// (`DifficultyBand(wheelSize:)`), not `seed.band` — `DailyPuzzle` picks
    /// `seed.band` assuming the old theme-lexicon wheel-length flow, which
    /// this bypasses; using the real wheel size keeps the word-count target
    /// scaled to what's actually achievable.
    public func dailyLevel(for seed: LevelSeed, word: String) -> Level {
        let creatureID = SceneCreaturePicker(pools: pools).pick(theme: seed.theme, index: seed.index).creatureID
        let band = DifficultyBand(wheelSize: word.count)
        return Level(
            id: seed.id,
            wheel: Wheel(letters: word),
            slots: [],
            sceneID: WordOfTheDayImages.slug(forWord: word, theme: seed.theme),
            creatureID: creatureID,
            format: .pangramHunt(target: PackCatalog.pangramTarget(for: band))
        )
    }
}
