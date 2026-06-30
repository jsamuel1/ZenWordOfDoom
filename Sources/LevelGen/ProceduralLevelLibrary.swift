import Foundation
import GameCore

/// Deterministic ordered sequence of level seeds. Order N maps to a stable
/// `LevelSeed`; ids are reversible so progress can be keyed by id.
public struct ProceduralLevelLibrary: Sendable {
    public let packSize: Int
    public init(packSize: Int = 10) { self.packSize = packSize }

    private static let bandOrder: [DifficultyBand] = [.easy, .medium, .hard, .expert, .master]

    public func seed(atOrder order: Int) -> LevelSeed {
        let pack = order / packSize
        let theme: Theme = (pack % 2 == 0) ? .zen : .doom
        let bandIdx = min(pack, Self.bandOrder.count - 1)
        let band = Self.bandOrder[bandIdx]
        // Global order is the per-level index, keeping every id unique.
        return LevelSeed(theme: theme, band: band, index: order)
    }

    public func seed(forID id: String) -> LevelSeed? {
        let parts = id.split(separator: "-")
        guard parts.count == 3,
              let theme = Theme(rawValue: String(parts[0])),
              let band = DifficultyBand(rawValue: String(parts[1])),
              let index = Int(parts[2]) else { return nil }
        return LevelSeed(theme: theme, band: band, index: index)
    }
}
