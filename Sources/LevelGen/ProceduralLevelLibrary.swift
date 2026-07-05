import Foundation
import GameCore

/// Deterministic ordered sequence of level seeds. Order N maps to a stable
/// `LevelSeed`; ids are reversible so progress can be keyed by id.
public struct ProceduralLevelLibrary: Sendable {
    public let packSize: Int
    public init(packSize: Int = 10) { self.packSize = packSize }

    private static let bandOrder: [DifficultyBand] = [.easy, .medium, .hard, .expert, .master]

    /// Order N maps to a stable `LevelSeed`. Difficulty is a 2-D ladder:
    /// each pack walks one wheel size, sizes cycle 5→9 across packs, and
    /// every full size cycle (5 packs) escalates the richness tier
    /// (easy → medium → hard word pools; see `DifficultyTier`). That gives a
    /// ~150-level ramp — packs 1-5 walk sizes at easy tier, 6-10 re-walk
    /// them at medium, 11-15 at hard — and the infinite tail keeps cycling
    /// sizes at hard tier instead of flat-lining on one wheel size.
    /// (Pre-schema-v2 saves keyed progress to the old always-master tail;
    /// the save migration resets level progress, see `GameStore`.)
    ///
    /// Theme starts at `.zen` and permanently swaps (zen<->doom) each time a
    /// prime-numbered level (1-indexed, as shown to the player) is crossed —
    /// an even count of primes seen so far means zen, odd means doom, so a
    /// pack of levels can contain a mix of themes.
    public func seed(atOrder order: Int) -> LevelSeed {
        let pack = order / packSize
        let band = Self.bandOrder[pack % Self.bandOrder.count]
        let levelNumber = order + 1
        let theme: Theme = Primes.count(upTo: levelNumber).isMultiple(of: 2) ? .zen : .doom
        // Global order is the per-level index, keeping every id unique.
        return LevelSeed(theme: theme, band: band, index: order)
    }

    /// The richness tier for an order: escalates once per full size cycle
    /// (`bandOrder.count` packs) and stays `.hard` forever after.
    public func tier(atOrder order: Int) -> DifficultyTier {
        let era = (order / packSize) / Self.bandOrder.count
        let tiers = DifficultyTier.allCases
        return tiers[min(era, tiers.count - 1)]
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
