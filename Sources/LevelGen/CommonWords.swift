import Foundation

/// Common English words (bundled `common-words.txt`, derived from the public-
/// domain google-10000-english list, filtered to 3–9 letters). Used to bias
/// level generation toward familiar, real dictionary words over obscure corpus
/// entries — common words are by definition recognizable and in the dictionary.
public struct CommonWords: Sendable {
    public static let shared = CommonWords()

    private let words: Set<String>
    public init() {
        self.words = Set(Self.load())
    }

    public var count: Int { words.count }

    public func contains(_ word: String) -> Bool {
        words.contains(word.uppercased())
    }

    private static func load() -> [String] {
        guard let url = Bundle.module.url(forResource: "common-words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
