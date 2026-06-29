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

    public init() {
        self.levelsCleared = 0
        self.totalWordsFound = 0
        self.totalBonusWords = 0
        self.longestWord = ""
        self.pangrams = 0
        self.creaturesRevealed = 0
        self.currentStreak = 0
        self.bestStreak = 0
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

    /// Record clearing a level: bumps cleared count and advances the streak.
    public mutating func recordClear() {
        levelsCleared += 1
        currentStreak += 1
        if currentStreak > bestStreak {
            bestStreak = currentStreak
        }
    }
}
