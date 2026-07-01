import Foundation

public extension Wheel {
    /// A deterministic permutation of the wheel's tile ids for on-screen tile
    /// placement. Shuffling positions never changes the letter set — the tiles
    /// keep their ids, only their order around the circle changes. `salt`
    /// re-rolls the order (e.g. a Shuffle-button press) while staying
    /// reproducible for a given `seed`/`salt`.
    func displayOrder(seed: UInt64, salt: UInt64 = 0) -> [Int] {
        var gen = SeededRandom(seed: seed &+ salt &* 0x9E3779B97F4A7C15)
        return tiles.map(\.id).shuffled(using: &gen)
    }
}
