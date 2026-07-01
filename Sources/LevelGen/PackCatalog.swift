import Foundation
import GameCore

/// A named group of levels. Identity is overlaid on the infinite level order:
/// every `packSize` levels is one pack, and each pack's last level (the
/// capstone) is a Pangram-Hunt boss that reveals a signature creature.
public struct Pack: Sendable, Equatable {
    public let index: Int
    public let name: String
    public let flavor: String

    public init(index: Int, name: String, flavor: String) {
        self.index = index
        self.name = name
        self.flavor = flavor
    }
}

/// Pure mapping from level order to pack identity, capstone detection, and the
/// per-band Pangram-Hunt target. No state; safe to share.
public struct PackCatalog: Sendable {
    public static let standard = PackCatalog()

    /// Evocative pack names, cycled for orders beyond the list.
    private let named: [(name: String, flavor: String)] = [
        ("Still Waters", "Where the pond holds its breath."),
        ("The Mossward", "Green over stone, and something beneath."),
        ("Ashen Deep", "The moor forgets the living."),
        ("Lantern Reach", "Small lights against a long dark."),
        ("Sunken Vigil", "The temple keeps its drowned watch."),
        ("Thorn Hollows", "Every path here has teeth."),
        ("Misted Ascent", "The peak withholds its summit."),
        ("Ember Vaults", "The catacombs are still warm."),
    ]

    public init() {}

    /// True when `order` is the last level of its pack.
    public func isCapstone(order: Int, packSize: Int) -> Bool {
        guard packSize > 0 else { return false }
        return order % packSize == packSize - 1
    }

    /// The pack an order belongs to.
    public func pack(forOrder order: Int, packSize: Int) -> Pack {
        let idx = max(0, packSize > 0 ? order / packSize : 0)
        let entry = named.isEmpty ? (name: "Pack \(idx + 1)", flavor: "") : named[idx % named.count]
        return Pack(index: idx, name: entry.name, flavor: entry.flavor)
    }

    /// The signature creature revealed at a pack's capstone, chosen
    /// deterministically from the theme's pool so it matches the capstone
    /// level's theme (and the Doom-only bestiary rule).
    public func signatureCreatureID(forOrder order: Int, packSize: Int,
                                    theme: Theme, pools: ThemePools) -> String {
        let creatures = (pools.creatures[theme] ?? []).sorted()
        guard !creatures.isEmpty else { return "" }
        let idx = max(0, packSize > 0 ? order / packSize : 0)
        return creatures[idx % creatures.count]
    }

    /// How many words a Pangram-Hunt boss requires, scaling with band.
    public static func pangramTarget(for band: DifficultyBand) -> Int {
        switch band {
        case .easy:   return 4
        case .medium: return 5
        case .hard:   return 6
        case .expert: return 7
        case .master: return 8
        }
    }
}
