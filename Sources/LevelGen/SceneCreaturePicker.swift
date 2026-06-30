import Foundation
import GameCore

public struct ThemePools: Sendable {
    public let scenes: [Theme: [String]]
    public let creatures: [Theme: [String]]
    public init(scenes: [Theme: [String]], creatures: [Theme: [String]]) {
        self.scenes = scenes
        self.creatures = creatures
    }
}

public extension ThemePools {
    /// Default curated themed asset ids. Slugs are evocative and IP-free so a
    /// later image-generation source can map them to prompts within content
    /// guardrails (mood over monsters).
    static let zenDoom = ThemePools(
        scenes: [
            .zen: ["still-pond", "moss-garden", "bamboo-grove", "misty-peak",
                   "lantern-path", "sand-ripples", "willow-bank"],
            .doom: ["sunken-crypt", "black-abyss", "thorn-hollow", "ruined-shrine",
                    "ashen-moor", "drowned-temple", "ember-catacomb"],
        ],
        creatures: [
            .zen: ["koi-spirit", "stone-guardian", "crane-shade", "lotus-wisp",
                   "moss-golem", "paper-fox"],
            .doom: ["deep-tentacle", "gloom-eye", "bone-wraith", "mask-fiend",
                    "thorn-revenant", "ash-maw"],
        ]
    )
}

public struct SceneCreaturePicker: Sendable {
    private let pools: ThemePools
    public init(pools: ThemePools) { self.pools = pools }

    public func pick(theme: Theme, index: Int) -> (sceneID: String, creatureID: String) {
        let scenes = (pools.scenes[theme] ?? []).sorted()
        let creatures = (pools.creatures[theme] ?? []).sorted()
        precondition(!scenes.isEmpty && !creatures.isEmpty, "empty pool for \(theme)")
        var rng = SeededRandom(seed: WheelPicker.seed(theme: theme, band: .easy, index: index) ^ 0xC0FFEE)
        let scene = scenes[Int(rng.next() % UInt64(scenes.count))]
        let creature = creatures[Int(rng.next() % UInt64(creatures.count))]
        return (scene, creature)
    }
}
