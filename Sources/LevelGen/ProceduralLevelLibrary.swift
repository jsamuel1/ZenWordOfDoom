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

    /// A shared default instance so progression and generation order levels identically.
    public static let standard = ProceduralLevelLibrary()

    public func id(atOrder order: Int) -> String { seed(atOrder: order).id }
    public func order(forID id: String) -> Int? { seed(forID: id)?.index }
    public func nextID(after id: String) -> String? {
        guard let order = order(forID: id) else { return nil }
        return self.id(atOrder: order + 1)
    }
    public func ids(through order: Int) -> [String] {
        guard order >= 0 else { return [] }
        return (0...order).map(id(atOrder:))
    }
    public func wheelSize(forID id: String) -> Int {
        guard let seed = seed(forID: id) else { return 0 }
        return WheelPicker.wheelLength(for: seed.band)
    }
}
