import Foundation
import GameCore

/// The daily puzzle: one fixed-seed level per calendar day (SPEC §8), the same
/// for every player. Ids are `daily-yyyy-MM-dd`; the seed is FNV-1a over the id,
/// so it is stable across devices and app versions.
public enum DailyPuzzle {
    public static func isDailyID(_ id: String) -> Bool { id.hasPrefix("daily-") }

    public static func id(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "daily-%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Seed for a daily id, or nil if the id isn't a well-formed daily date.
    /// Band rotates through the mid-game (never a 5-letter warm-up, never the
    /// 9-letter deep end); theme flips on the hash.
    public static func seed(forID id: String) -> LevelSeed? {
        guard dateComponents(forID: id) != nil else { return nil }
        let h = FNV1a.hash(id)
        let theme: Theme = h % 2 == 0 ? .zen : .doom
        let bands: [DifficultyBand] = [.medium, .hard, .expert]
        let band = bands[Int((h >> 8) % 3)]
        // Large offset keeps daily indices clear of the campaign's early orders
        // in generated content, without colliding ids (dailies re-key by date).
        let index = 1_000_000 + Int((h >> 16) % 1_000_000)
        return LevelSeed(theme: theme, band: band, index: index)
    }

    /// The curated Word of the Day for this daily id, and the theme it
    /// belongs to (always the same theme `seed(forID:)` picks for this id —
    /// there is only one theme decision per day, shared by both the word and
    /// the level's scene/creature pool). Nil for a malformed id.
    public static func wordOfTheDay(forID id: String) -> (theme: Theme, word: String)? {
        guard let (year, month, day) = dateComponents(forID: id),
              let seed = seed(forID: id) else { return nil }
        let dayNumber = daysFromCivil(year: year, month: month, day: day)
        return (seed.theme, WordOfTheDay.word(forTheme: seed.theme, dayNumber: dayNumber))
    }

    /// Parses and validates the `yyyy-MM-dd` suffix of a daily id. Shared by
    /// `seed(forID:)` and `wordOfTheDay(forID:)` so both agree on what counts
    /// as a valid daily id.
    private static func dateComponents(forID id: String) -> (year: Int, month: Int, day: Int)? {
        guard isDailyID(id) else { return nil }
        let day = String(id.dropFirst("daily-".count))
        let parts = day.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d), y >= 2026 else { return nil }
        return (y, m, d)
    }

    /// Days since 1970-01-01, pure integer arithmetic (Howard Hinnant's
    /// days-from-civil algorithm) — deliberately avoids Foundation's
    /// `Calendar`/`TimeZone` for a value that must be bit-for-bit identical
    /// on every device: the epoch and exact day count don't matter, only
    /// that it's a stable, monotonically increasing integer per calendar day.
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
}
