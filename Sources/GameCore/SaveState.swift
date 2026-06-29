import Foundation

/// Per-level progress record.
public struct LevelProgress: Codable, Equatable, Sendable {
    public var levelID: String
    public var cleared: Bool
    public var bestScore: Int
    public var bonusWordsFound: Int
    public var noHint: Bool

    public init(levelID: String,
                cleared: Bool = false,
                bestScore: Int = 0,
                bonusWordsFound: Int = 0,
                noHint: Bool = false) {
        self.levelID = levelID
        self.cleared = cleared
        self.bestScore = bestScore
        self.bonusWordsFound = bonusWordsFound
        self.noHint = noHint
    }
}

/// A creature unlocked in the bestiary.
public struct BestiaryEntry: Codable, Equatable, Sendable {
    public var creatureID: String
    public var firstRevealedLevelID: String

    public init(creatureID: String, firstRevealedLevelID: String) {
        self.creatureID = creatureID
        self.firstRevealedLevelID = firstRevealedLevelID
    }
}

/// The full persisted player profile.
public struct SaveState: Codable, Equatable, Sendable {
    public var serenity: Int
    public var stats: GameStats
    public var progress: [String: LevelProgress]
    public var bestiary: [String: BestiaryEntry]

    public init() {
        self.serenity = 0
        self.stats = GameStats()
        self.progress = [:]
        self.bestiary = [:]
    }
}
