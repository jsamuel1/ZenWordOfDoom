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
