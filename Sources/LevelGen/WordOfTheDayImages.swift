import Foundation

/// Picks a shared illustration slug for a curated Word of the Day (design
/// spec §4.4 — many words per image). A slug's art is bundled/generated
/// exactly like the existing scene art: the word's slug simply becomes that
/// day's `Level.sceneID`, reusing the existing `.scene` visual kind.
///
/// There is deliberately NO per-word mapping table: the word→image pairing
/// is computed by `SceneAffinity` from the slug's own words ("dawn-glow" →
/// DAWN, GLOW), so growing the art library is just appending a slug below
/// (plus its bundled asset) — every curated word immediately reconsiders the
/// new image with zero curation.
public enum WordOfTheDayImages {
    public static func slugs(for theme: Theme) -> [String] {
        slugsByTheme[theme] ?? []
    }

    /// The illustration slug for a curated word: a deterministic,
    /// load-balanced affinity assignment (each word takes its
    /// highest-affinity slug among the least-used slugs so far, in
    /// alphabetical word order). Balancing keeps every bundled image in use
    /// (pure argmax left some slugs orphaned) while affinity still steers
    /// each word to the best of the remaining candidates. A word outside the
    /// curated lists falls back to plain best-affinity.
    public static func slug(forWord word: String, theme: Theme) -> String {
        if let assigned = balancedAssignments[theme]?[word.uppercased()] {
            return assigned
        }
        return bestAffinitySlug(forWord: word, among: slugsByTheme[theme] ?? [])
    }

    /// Highest-affinity slug in `candidates` (ties break alphabetically).
    private static func bestAffinitySlug(forWord word: String, among candidates: [String]) -> String {
        guard var best = candidates.first else { return "" }
        var bestScore = SceneAffinity.score(anchor: word, slug: best)
        for slug in candidates.dropFirst() {
            let score = SceneAffinity.score(anchor: word, slug: slug)
            if score > bestScore || (score == bestScore && slug < best) {
                best = slug
                bestScore = score
            }
        }
        return best
    }

    /// Word → slug for every curated Word of the Day, computed once.
    private static let balancedAssignments: [Theme: [String: String]] = {
        var byTheme: [Theme: [String: String]] = [:]
        for theme in Theme.allCases {
            let slugs = slugsByTheme[theme] ?? []
            guard !slugs.isEmpty else { continue }
            var load: [String: Int] = Dictionary(uniqueKeysWithValues: slugs.map { ($0, 0) })
            var assignment: [String: String] = [:]
            for word in WordOfTheDay.words(for: theme).sorted() {
                let minLoad = load.values.min() ?? 0
                let leastUsed = slugs.filter { load[$0] == minLoad }
                let slug = bestAffinitySlug(forWord: word, among: leastUsed)
                assignment[word] = slug
                load[slug, default: 0] += 1
            }
            byTheme[theme] = assignment
        }
        return byTheme
    }()

    private static let slugsByTheme: [Theme: [String]] = [
        .zen: ["dawn-glow", "moonlit-hush", "still-water", "quiet-garden",
               "lantern-calm", "gentle-breath", "drifting-ease", "warm-heart",
               "nurtured-soul", "calm-balance", "soft-whisper", "graceful-harmony"],
        .doom: ["ashen-ruin", "black-crypt", "cursed-hollow", "gravebound",
                "festering-dark", "shrieking-night", "monstrous-thing", "forsaken-tomb",
                "venomous-rite", "spectral-dread", "ravaged-earth", "malevolent-omen"],
    ]
}
