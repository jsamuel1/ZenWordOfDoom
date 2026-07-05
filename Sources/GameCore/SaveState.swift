import Foundation

/// Per-level progress record.
public struct LevelProgress: Codable, Equatable, Sendable {
    public var levelID: String
    public var cleared: Bool
    public var bestScore: Int
    public var bonusWordsFound: Int
    public var noHint: Bool
    /// How many bonus words have already paid serenity on this level —
    /// capped at `Economy.maxBonusRewardsPerLevel`, persisted so relaunching
    /// mid-level can't reset the meter.
    public var serenityBonusPaid: Int

    public init(levelID: String,
                cleared: Bool = false,
                bestScore: Int = 0,
                bonusWordsFound: Int = 0,
                noHint: Bool = false,
                serenityBonusPaid: Int = 0) {
        self.levelID = levelID
        self.cleared = cleared
        self.bestScore = bestScore
        self.bonusWordsFound = bonusWordsFound
        self.noHint = noHint
        self.serenityBonusPaid = serenityBonusPaid
    }

    // MARK: Codable — tolerant of older saves (same contract as SaveState:
    // every field defaults, so entries written before a key existed decode
    // intact instead of failing the whole profile).

    private enum CodingKeys: String, CodingKey {
        case levelID, cleared, bestScore, bonusWordsFound, noHint, serenityBonusPaid
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.levelID = try c.decodeIfPresent(String.self, forKey: .levelID) ?? ""
        self.cleared = try c.decodeIfPresent(Bool.self, forKey: .cleared) ?? false
        self.bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        self.bonusWordsFound = try c.decodeIfPresent(Int.self, forKey: .bonusWordsFound) ?? 0
        self.noHint = try c.decodeIfPresent(Bool.self, forKey: .noHint) ?? false
        self.serenityBonusPaid = try c.decodeIfPresent(Int.self, forKey: .serenityBonusPaid) ?? 0
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
    /// Bump when a release invalidates part of an older profile (see
    /// `GameStore`'s migration for what each bump resets). Distinct from the
    /// additive-key tolerance below, which handles *new fields* silently;
    /// this handles *meaning changes* to existing data explicitly.
    ///
    /// - v1 (implicit; saves without the key): through v0.4.x.
    /// - v2: level content regenerated wholesale (known-good anchor pools +
    ///   tiered difficulty ladder) — saved level progress no longer describes
    ///   the puzzles it points at, so migration clears `progress` only.
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var serenity: Int
    public var stats: GameStats
    public var progress: [String: LevelProgress]
    public var bestiary: [String: BestiaryEntry]

    // MARK: Monetization / cosmetics (added v0.3)

    /// Mirrored StoreKit entitlement to the remove-ads premium, so ad gating
    /// works offline. StoreKit remains the source of truth when reachable.
    public var premiumUnlocked: Bool
    /// Cosmetic ids (palettes, poem sets) unlocked with serenity.
    public var ownedCosmetics: Set<String>
    /// Equipped cosmetic choices; nil = the built-in default.
    public var equippedPalette: String?
    public var equippedPoemSet: String?
    /// Recently processed StoreKit transaction ids, so a replayed unfinished
    /// consumable transaction can't credit serenity twice. Bounded (see
    /// `markTransactionProcessed`).
    public var processedTransactionIDs: [UInt64]

    public init() {
        self.schemaVersion = Self.currentSchemaVersion
        self.serenity = Economy.startingSerenity
        self.stats = GameStats()
        self.progress = [:]
        self.bestiary = [:]
        self.premiumUnlocked = false
        self.ownedCosmetics = []
        self.equippedPalette = nil
        self.equippedPoemSet = nil
        self.processedTransactionIDs = []
    }

    /// Record a transaction id as delivered. Returns `false` (and records
    /// nothing new) when the id was already processed — the caller must skip
    /// crediting. Keeps only the most recent ids so the list can't grow forever.
    @discardableResult
    public mutating func markTransactionProcessed(_ id: UInt64) -> Bool {
        guard !processedTransactionIDs.contains(id) else { return false }
        processedTransactionIDs.append(id)
        if processedTransactionIDs.count > 50 {
            processedTransactionIDs.removeFirst(processedTransactionIDs.count - 50)
        }
        return true
    }

    // MARK: Codable — tolerant of older saves

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case serenity, stats, progress, bestiary
        case premiumUnlocked, ownedCosmetics, equippedPalette, equippedPoemSet
        case processedTransactionIDs
    }

    /// Every field decodes with a default so profiles written by any earlier
    /// version (which lack the newer keys) load intact instead of falling back
    /// to a fresh save. A save without `schemaVersion` is v1 (pre-v0.5) —
    /// deliberately decoded as 1, NOT the current version, so `GameStore`
    /// can tell it needs migration.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.serenity = try c.decodeIfPresent(Int.self, forKey: .serenity) ?? 0
        self.stats = try c.decodeIfPresent(GameStats.self, forKey: .stats) ?? GameStats()
        self.progress = try c.decodeIfPresent([String: LevelProgress].self, forKey: .progress) ?? [:]
        self.bestiary = try c.decodeIfPresent([String: BestiaryEntry].self, forKey: .bestiary) ?? [:]
        self.premiumUnlocked = try c.decodeIfPresent(Bool.self, forKey: .premiumUnlocked) ?? false
        self.ownedCosmetics = try c.decodeIfPresent(Set<String>.self, forKey: .ownedCosmetics) ?? []
        self.equippedPalette = try c.decodeIfPresent(String.self, forKey: .equippedPalette)
        self.equippedPoemSet = try c.decodeIfPresent(String.self, forKey: .equippedPoemSet)
        self.processedTransactionIDs = try c.decodeIfPresent([UInt64].self, forKey: .processedTransactionIDs) ?? []
    }
}
