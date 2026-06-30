import Foundation
import GameCore

/// The bundled ENABLE general word list (uppercase, 3–9 letter words). The
/// source of every real word a wheel can build.
public struct GeneralWordList: Sendable {
    public static let shared = GeneralWordList()

    private let words: [String]
    public init() { self.words = Self.load() }

    public var count: Int { words.count }

    /// All corpus words buildable from `multiset` with length >= `minLength`.
    public func buildableWords(from multiset: LetterMultiset, minLength: Int = 3) -> [String] {
        words.filter { $0.count >= minLength && multiset.canBuild($0) }
    }

    private static func load() -> [String] {
        guard let url = Bundle.module.url(forResource: "words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
