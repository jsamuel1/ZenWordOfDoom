import Foundation
import GameCore

/// A simple set-backed dictionary. v1 placeholder for the eventual bundled
/// DAWG/trie (see docs/ARCHITECTURE.md §4); the `WordValidating` interface is
/// identical, so swapping the backing store later is transparent.
public struct InMemoryDictionary: WordValidating {
    private let words: Set<String>

    public init(words: some Sequence<String>) {
        self.words = Set(words.map { $0.uppercased() })
    }

    /// Load from a newline-separated word list resource.
    public init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        self.init(words: text.split(whereSeparator: \.isNewline).map(String.init))
    }

    public func isValidWord(_ word: String) -> Bool {
        words.contains(word.uppercased())
    }

    public var count: Int { words.count }

    /// Every dictionary word buildable from a wheel's letters, length >= min.
    public func words(buildableFrom multiset: LetterMultiset, minLength: Int = 3) -> [String] {
        words.filter { $0.count >= minLength && multiset.canBuild($0) }.sorted()
    }
}
