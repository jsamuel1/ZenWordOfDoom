import Foundation

/// Pre-selected "known good" wheel anchors, one pool per wheel length (5–9),
/// generated offline by `scripts/generate-anchor-pools.sh` and bundled as
/// `Resources/anchor-pools.json`.
///
/// Every anchor is quality-gated against the game's own corpus (`words.txt`
/// + `common-words.txt`, both ESDB-derived): the anchor is itself a common
/// word (it is the guaranteed pangram on capstone/boss levels), and the
/// number of COMMON words buildable from its letters meets a per-length
/// floor (15/25/40/55/70 for lengths 5/6/7/8/9), so no wheel drawn from
/// here can be word-poor or force obscure grid answers. Pools are
/// de-duplicated by letter multiset (anagrams are the same wheel) and
/// capped at the best 250 per length.
public struct AnchorPools: Sendable {
    public static let shared = AnchorPools()

    private let byLength: [Int: [String]]

    public init() { self.byLength = Self.load() }

    /// Known-good anchors of exactly `length` letters, alphabetical.
    /// Empty for a length with no bundled pool.
    public func anchors(ofLength length: Int) -> [String] {
        byLength[length] ?? []
    }

    private static func load() -> [Int: [String]] {
        guard let url = Bundle.module.url(forResource: "anchor-pools", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        var out: [Int: [String]] = [:]
        for (key, words) in raw {
            guard let n = Int(key) else { continue }
            out[n] = words.map { $0.uppercased() }
        }
        return out
    }
}
