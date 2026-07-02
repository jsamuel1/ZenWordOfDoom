import Foundation

public enum CosmeticKind: String, Codable, Sendable {
    case palette
    case poemSet
}

/// One unlockable cosmetic, bought with serenity in the Shrine.
public struct Cosmetic: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: CosmeticKind
    public let name: String
    public let flavor: String
    /// Serenity cost (spec: ~25–75, inside the small-number economy).
    public let cost: Int

    public init(id: String, kind: CosmeticKind, name: String, flavor: String, cost: Int) {
        self.id = id
        self.kind = kind
        self.name = name
        self.flavor = flavor
        self.cost = cost
    }
}

/// The fixed v0.3 cosmetic catalog: scene palettes recolor the level reveal;
/// poem sets swap the cut-scene verses. Content, not code — extend freely.
public enum CosmeticsCatalog {
    public static let all: [Cosmetic] = [
        Cosmetic(id: "palette-ember", kind: .palette,
                 name: "Ember Dusk", flavor: "The garden remembers fire.", cost: 40),
        Cosmetic(id: "palette-moonlit", kind: .palette,
                 name: "Moonlit Frost", flavor: "Cold light on colder water.", cost: 40),
        Cosmetic(id: "palette-bloom", kind: .palette,
                 name: "First Bloom", flavor: "Petals over the abyss.", cost: 25),
        Cosmetic(id: "poems-deep", kind: .poemSet,
                 name: "Verses of the Deep", flavor: "The abyss writes back.", cost: 60),
        Cosmetic(id: "poems-dawn", kind: .poemSet,
                 name: "Dawn Verses", flavor: "Morning holds its breath.", cost: 60),
    ]

    public static func cosmetic(id: String) -> Cosmetic? {
        all.first { $0.id == id }
    }

    public static func items(of kind: CosmeticKind) -> [Cosmetic] {
        all.filter { $0.kind == kind }
    }
}
