import Foundation

/// Curated atmospheric anchor words per theme. Used to pick themed base words
/// and to score candidate words by theme affinity.
public struct ThemeLexicon: Sendable {
    public static let shared = ThemeLexicon()

    private let byTheme: [Theme: Set<String>]
    public init() {
        var map: [Theme: Set<String>] = [:]
        for theme in Theme.allCases {
            map[theme] = Set(Self.load(resource: "seed-\(theme.rawValue)"))
        }
        self.byTheme = map
    }

    public func words(for theme: Theme) -> Set<String> { byTheme[theme] ?? [] }

    public func contains(_ word: String, theme: Theme) -> Bool {
        byTheme[theme]?.contains(word.uppercased()) ?? false
    }

    private static func load(resource: String) -> [String] {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
