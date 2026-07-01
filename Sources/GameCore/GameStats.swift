import Foundation

/// Aggregate lifetime statistics across all play.
public struct GameStats: Codable, Equatable, Sendable {
    public var levelsCleared: Int
    public var totalWordsFound: Int
    public var totalBonusWords: Int
    public var longestWord: String
    public var pangrams: Int
    public var creaturesRevealed: Int
    public var currentStreak: Int
    public var bestStreak: Int
    /// Ordinal day number of the last day the player recorded activity, or nil if
    /// never. Optional so existing saved profiles (without this key) still decode.
    public var lastPlayedDay: Int?

    public init() {
        self.levelsCleared = 0
        self.totalWordsFound = 0
        self.totalBonusWords = 0
        self.longestWord = ""
        self.pangrams = 0
        self.creaturesRevealed = 0
        self.currentStreak = 0
        self.bestStreak = 0
        self.lastPlayedDay = nil
    }

    /// Record any found word (grid or bonus). A pangram also bumps the pangram count.
    public mutating func recordWord(_ w: String, isBonus: Bool, isPangram: Bool) {
        let word = w.uppercased()
        totalWordsFound += 1
        if isBonus { totalBonusWords += 1 }
        if isPangram { pangrams += 1 }
        if word.count > longestWord.count {
            longestWord = word
        }
    }

    /// Record clearing a level: bumps the cleared count. The streak is a *daily*
    /// streak, advanced separately by `recordPlay(dayNumber:)`.
    public mutating func recordClear() {
        levelsCleared += 1
    }

    /// Advance the daily streak. `dayNumber` is an ordinal day (e.g. days since a
    /// fixed era); consecutive days extend the streak, a gap resets it to 1, and
    /// multiple plays in the same day are idempotent.
    public mutating func recordPlay(dayNumber: Int) {
        guard dayNumber > 0 else { return }
        if let last = lastPlayedDay {
            if last == dayNumber { return }                    // already counted today
            currentStreak = (last == dayNumber - 1) ? currentStreak + 1 : 1
        } else {
            currentStreak = 1
        }
        lastPlayedDay = dayNumber
        if currentStreak > bestStreak { bestStreak = currentStreak }
    }
}
