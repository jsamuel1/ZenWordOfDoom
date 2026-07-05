import Foundation
import GameCore

/// Scores how well a wheel anchor "belongs" to an illustration, using only
/// the illustration's slug — the slug's hyphen-separated words ARE its
/// metadata ("moss-garden" → MOSS, GARDEN). Adding a new image therefore
/// needs no word lists or mapping tables: name the asset evocatively and
/// every affinity-based selection picks it up automatically.
public enum SceneAffinity {
    /// Tag words derived from a slug: hyphen components, uppercased,
    /// non-letters stripped.
    public static func tags(forSlug slug: String) -> [String] {
        slug.split(separator: "-")
            .map { String($0).uppercased().filter(\.isLetter) }
            .filter { !$0.isEmpty }
    }

    /// Deterministic affinity between an anchor's letters and a slug's tags.
    /// A tag word fully buildable from the anchor scores strongly — the
    /// scene's own word is spellable on that wheel — otherwise the tag
    /// contributes its letter overlap, so every (anchor, slug) pair gets a
    /// comparable score and ties break elsewhere (alphabetically, by the
    /// callers). Higher is better; always >= 0.
    public static func score(anchor: String, slug: String) -> Int {
        let upper = anchor.uppercased()
        let multiset = LetterMultiset(upper)
        var total = 0
        for tag in tags(forSlug: slug) {
            if tag.count >= 3, multiset.canBuild(tag) {
                total += 100 + tag.count * 10
            } else {
                total += overlap(upper, tag)
            }
        }
        return total
    }

    /// Multiset letter overlap |anchor ∩ tag|.
    private static func overlap(_ anchor: String, _ tag: String) -> Int {
        var counts: [Character: Int] = [:]
        for ch in anchor { counts[ch, default: 0] += 1 }
        var shared = 0
        for ch in tag where counts[ch, default: 0] > 0 {
            counts[ch]! -= 1
            shared += 1
        }
        return shared
    }
}
