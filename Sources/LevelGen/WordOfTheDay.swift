import Foundation
import GameCore

/// The curated Word of the Day: a hand-picked list of evocative 8-10 letter
/// Zen/Doom words, bundled per theme (`Resources/daily-<theme>.txt`), plus
/// deterministic per-day selection so every player sees the same word.
///
/// Selection uses a per-cycle Fisher-Yates shuffle (our own `SeededRandom`,
/// never the standard library's `shuffled(using:)` — its algorithm isn't a
/// documented, version-stable contract, and this needs to produce the exact
/// same word on the exact same day forever, the same way `FNV1a`'s offset
/// basis is pinned rather than "corrected"). A day-number-modulo-cycle-length
/// pick guarantees a theme's list never repeats a word until every word in
/// it has been used once; the cycle number reseeds the shuffle so the next
/// pass through the list uses a different order, not the same one again.
public enum WordOfTheDay {
    public static func words(for theme: Theme) -> [String] {
        byTheme[theme] ?? []
    }

    /// The word for a given theme and day number (days since a fixed epoch —
    /// see `DailyPuzzle.daysFromCivil`, Task 3). Always the same word for the
    /// same (theme, dayNumber) pair, on every device, forever.
    public static func word(forTheme theme: Theme, dayNumber: Int) -> String {
        let list = words(for: theme)
        precondition(!list.isEmpty, "no Word-of-the-Day list for \(theme)")
        let cycleLength = list.count
        let cycleIndex = dayNumber % cycleLength
        let cycleNumber = dayNumber / cycleLength
        let seed = FNV1a.hash("wotd-\(theme.rawValue)-\(cycleNumber)")
        return fisherYatesShuffle(list, seed: seed)[cycleIndex]
    }

    private static func fisherYatesShuffle(_ items: [String], seed: UInt64) -> [String] {
        var rng = SeededRandom(seed: seed)
        var array = items
        guard array.count > 1 else { return array }
        for i in stride(from: array.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            array.swapAt(i, j)
        }
        return array
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
