import Foundation
import GameCore

/// The bundled general word corpus (uppercase, 3–9 letter words; ESDB/SCOWL-
/// derived — regenerate via `scripts/generate-word-corpus.sh`). The source of
/// every real word a wheel can build, and the membership authority the
/// pre-selected anchor pools are validated against.
public struct GeneralWordList: Sendable {
    public static let shared = GeneralWordList()

    private let words: [String]
    private let wordSet: Set<String>
    public init() {
        self.words = Self.load()
        self.wordSet = Set(words)
    }

    public var count: Int { words.count }

    /// All corpus words buildable from `multiset` with length >= `minLength`.
    public func buildableWords(from multiset: LetterMultiset, minLength: Int = 3) -> [String] {
        words.filter { $0.count >= minLength && multiset.canBuild($0) }
    }

    /// True if `word` (case-insensitive) is present in the corpus.
    public func contains(_ word: String) -> Bool {
        wordSet.contains(word.uppercased())
    }

    private static func load() -> [String] {
        guard let url = Bundle.module.url(forResource: "words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
