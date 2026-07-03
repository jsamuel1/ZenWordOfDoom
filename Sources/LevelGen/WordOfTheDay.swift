import Foundation

/// The curated Word of the Day: a hand-picked list of evocative 8-10 letter
/// Zen/Doom words, bundled per theme (`Resources/daily-<theme>.txt`). This
/// file only loads and exposes the lists; day-based selection lives here too
/// (added in Task 2) so the whole "which word for which day" concern stays
/// in one small, pure, headlessly-testable type.
public enum WordOfTheDay {
    /// The curated list for a theme, in a fixed, well-defined base order
    /// (alphabetical) — the order Task 2's per-cycle shuffle starts from.
    public static func words(for theme: Theme) -> [String] {
        byTheme[theme] ?? []
    }

    private static let byTheme: [Theme: [String]] = {
        var map: [Theme: [String]] = [:]
        for theme in Theme.allCases {
            map[theme] = load(resource: "daily-\(theme.rawValue)").sorted()
        }
        return map
    }()

    private static func load(resource: String) -> [String] {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
