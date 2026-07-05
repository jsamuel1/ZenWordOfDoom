import Foundation

/// Pre-selected "known good" wheel anchors, one pool per (wheel length 5–9,
/// `DifficultyTier`), generated offline by `scripts/generate-anchor-pools.sh`
/// and bundled as `Resources/anchor-pools.json`.
///
/// Every anchor is quality-gated against the game's own corpus (`words.txt`
/// + `common-words.txt`, both ESDB-derived): the anchor is itself a common
/// word (it is the guaranteed pangram on capstone/boss levels), passes the
/// sanity gates (a vowel, ≥3 distinct letters, no letter more than twice),
/// and the number of COMMON words buildable from its letters falls in its
/// tier's per-length range — easy = rich pool (lots to find), hard = lean
/// pool (few possible words, same grid demands). Pools are de-duplicated by
/// letter multiset and capped at 200 per (length, tier).
public struct AnchorPools: Sendable {
    public static let shared = AnchorPools()

    private let byLength: [Int: [String: [String]]]

    public init() { self.byLength = Self.load() }

    /// Known-good anchors of exactly `length` letters in `tier`, alphabetical.
    /// Empty for a (length, tier) with no bundled pool.
    public func anchors(ofLength length: Int, tier: DifficultyTier) -> [String] {
        byLength[length]?[tier.rawValue] ?? []
    }

    /// All tiers of a length merged (alphabetical) — for membership checks
    /// and fallbacks; gameplay picks always go through a specific tier.
    public func anchors(ofLength length: Int) -> [String] {
        (byLength[length] ?? [:]).values.flatMap { $0 }.sorted()
    }

    private static func load() -> [Int: [String: [String]]] {
        guard let url = Bundle.module.url(forResource: "anchor-pools", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String: [String]]].self, from: data)
        else { return [:] }
        var out: [Int: [String: [String]]] = [:]
        for (key, tiers) in raw {
            guard let n = Int(key) else { continue }
            out[n] = tiers.mapValues { $0.map { $0.uppercased() } }
        }
        return out
    }
}
