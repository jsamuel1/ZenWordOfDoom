import Foundation
import GameCore

/// Corpus words buildable from the wheel, ranked to surface *interesting* words:
/// theme-lexicon (zen/doom) words first, then common/familiar dictionary words,
/// then longer words, then alphabetical. This biases grids toward recognizable,
/// themed words over obscure corpus entries. Capped at `limit`.
public struct DeterministicWordProvider: ThemedWordProvider {
    private let minLength: Int
    public init(minLength: Int = 3) { self.minLength = minLength }

    public func words(forWheel wheel: Wheel, theme: Theme, limit: Int) async throws -> [String] {
        let lexicon = ThemeLexicon.shared
        let common = CommonWords.shared
        let buildable = GeneralWordList.shared.buildableWords(from: wheel.multiset, minLength: minLength)
        return buildable.sorted { a, b in
            // 1. On-theme (zen/doom) words are the most interesting.
            let ta = lexicon.contains(a, theme: theme) ? 1 : 0
            let tb = lexicon.contains(b, theme: theme) ? 1 : 0
            if ta != tb { return ta > tb }
            // 2. Then common/familiar dictionary words over obscure corpus entries.
            let ca = common.contains(a) ? 1 : 0
            let cb = common.contains(b) ? 1 : 0
            if ca != cb { return ca > cb }
            // 3. Then longer words for richer grids, then alphabetical (stable).
            if a.count != b.count { return a.count > b.count }
            return a < b
        }
        .prefix(limit)
        .map { $0 }
    }
}
