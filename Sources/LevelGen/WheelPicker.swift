import Foundation
import GameCore

public enum WheelPicker {
    /// Wheel length (max word length) for a band.
    public static func wheelLength(for band: DifficultyBand) -> Int {
        switch band {
        case .easy: return 5
        case .medium: return 6
        case .hard: return 7
        case .expert: return 8
        case .master: return 9
        }
    }

    /// Deterministically pick a themed base word of the band's length from the
    /// theme lexicon; its letters form the wheel.
    ///
    /// Throws `LevelGenError.noAnchorWord` when the theme lexicon has no word
    /// of the required length — every real theme/band pair is covered (see
    /// `LevelGenErrorTests`), so this should never fire in practice.
    public static func wheel(theme: Theme, band: DifficultyBand, index: Int) throws -> Wheel {
        let n = wheelLength(for: band)
        let candidates = ThemeLexicon.shared.words(for: theme)
            .filter { $0.count == n }
            .sorted()
        guard !candidates.isEmpty else {
            throw LevelGenError.noAnchorWord(theme: theme, length: n)
        }
        var rng = SeededRandom(seed: seed(theme: theme, band: band, index: index))
        let pick = candidates[Int(rng.next() % UInt64(candidates.count))]
        return Wheel(letters: pick)
    }

    /// How many of the highest-affinity known-good anchors a scene cycles
    /// through per band. Also the guaranteed minimum spacing (in same-scene,
    /// same-band levels) before a wheel's letters can repeat.
    static let affinityCandidates = 24

    /// Scene-coupled wheel: pick from the pre-selected known-good anchor
    /// pools (`AnchorPools`), letting the scene's slug words steer WHICH
    /// known-good anchor is chosen — the image inspires the letters, but
    /// every candidate is quality-gated, so no scene can produce a word-poor
    /// wheel (previously scenes carried their own tiny fixed lexicons; some
    /// had a single 9-letter word, so master-band levels repeated letters on
    /// consecutive levels).
    ///
    /// Selection: rank the pool by `SceneAffinity` against the slug, keep the
    /// top `affinityCandidates`, lay them out in a per-(theme, scene, length)
    /// seeded Fisher–Yates cycle, and step through the cycle by `index`.
    /// Consecutive same-scene levels therefore always differ, and a wheel
    /// can only recur once the cycle wraps. Falls back to the theme-lexicon
    /// anchor path if the bundled pools are missing.
    ///
    /// `avoidingSignature` (a sorted-letters signature) skips past a cycle
    /// entry with those exact letters — the generator passes the previous
    /// level's signature so DIFFERENT scenes whose cycles happen to align
    /// can't serve the same letters two levels in a row either.
    public static func wheel(sceneID: String, theme: Theme, band: DifficultyBand, index: Int,
                             avoidingSignature: String? = nil) throws -> Wheel {
        let n = wheelLength(for: band)
        let pool = AnchorPools.shared.anchors(ofLength: n)
        guard !pool.isEmpty else { return try wheel(theme: theme, band: band, index: index) }

        let ranked = pool
            .map { (word: $0, score: SceneAffinity.score(anchor: $0, slug: sceneID)) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.word < $1.word }
            .prefix(affinityCandidates)
            .map(\.word)

        // Explicit Fisher–Yates with SeededRandom (never stdlib shuffle —
        // its algorithm isn't pinned across Swift versions; see WordOfTheDay).
        var cycle = Array(ranked)
        var rng = SeededRandom(seed: FNV1a.hash(theme.rawValue + sceneID + "\(n)"))
        var i = cycle.count - 1
        while i >= 1 {
            let j = Int(rng.next() % UInt64(i + 1))
            cycle.swapAt(i, j)
            i -= 1
        }

        var position = index % cycle.count
        if let avoid = avoidingSignature {
            // Cycle entries are multiset-distinct, so at most one can match;
            // the loop bound just guards a degenerate single-entry cycle.
            var attempts = 0
            while attempts < cycle.count, String(cycle[position].sorted()) == avoid {
                position = (position + 1) % cycle.count
                attempts += 1
            }
        }
        return Wheel(letters: cycle[position])
    }

    /// Stable FNV-1a seed for a (theme, band, index) triple.
    static func seed(theme: Theme, band: DifficultyBand, index: Int) -> UInt64 {
        FNV1a.hash(theme.rawValue + band.rawValue + "\(index)")
    }
}
