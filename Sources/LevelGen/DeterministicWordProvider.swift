import Foundation
import GameCore

/// Corpus words buildable from the wheel, ranked: theme-lexicon words first,
/// then longer words, then alphabetical. Capped at `limit`.
public struct DeterministicWordProvider: ThemedWordProvider {
    private let minLength: Int
    public init(minLength: Int = 3) { self.minLength = minLength }

    public func words(forWheel wheel: Wheel, theme: Theme, limit: Int) async throws -> [String] {
        let lexicon = ThemeLexicon.shared
        let buildable = GeneralWordList.shared.buildableWords(from: wheel.multiset, minLength: minLength)
        return buildable.sorted { a, b in
            let sa = lexicon.contains(a, theme: theme) ? 1 : 0
            let sb = lexicon.contains(b, theme: theme) ? 1 : 0
            if sa != sb { return sa > sb }
            if a.count != b.count { return a.count > b.count }
            return a < b
        }
        .prefix(limit)
        .map { $0 }
    }
}
