import Foundation
import Combine
import GameCore
import LevelGen

/// Owns the persisted `SaveState` and the rules for mutating it. Backed by a
/// JSON file in Application Support; every mutation persists immediately.
@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var state: SaveState

    private let fileURL: URL
    private let library = ProceduralLevelLibrary.standard

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true))
            ?? fm.temporaryDirectory
        self.fileURL = base.appendingPathComponent("ZenWordOfDoom.save.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(SaveState.self, from: data) {
            self.state = decoded
        } else {
            self.state = SaveState()
        }
    }

    /// Persist the current state to disk. Failures are swallowed — a missing
    /// save is recoverable (empty profile) and never worth crashing for.
    func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    /// Record a cleared level: updates per-level progress, lifetime stats, the
    /// bestiary, and awards serenity. Idempotent-ish — best score / best bonus
    /// only ever improve.
    func recordClear(level: Level,
                     score: Int,
                     bonusWords: Int,
                     usedHint: Bool,
                     creatureRevealed: Bool) {
        let wasCleared = state.progress[level.id]?.cleared ?? false

        var progress = state.progress[level.id] ?? LevelProgress(levelID: level.id)
        progress.cleared = true
        progress.bestScore = max(progress.bestScore, score)
        progress.bonusWordsFound = max(progress.bonusWordsFound, bonusWords)
        // noHint stays true only if it was a clean clear at least once.
        progress.noHint = progress.noHint || !usedHint
        state.progress[level.id] = progress

        state.stats.recordClear()

        // The daily streak advances on a *clear* (any level, dailies included),
        // not on merely opening the app — a streak you keep by playing.
        state.stats.recordPlay(dayNumber: Self.utcDayNumber())

        // Only Doom levels contribute to the bestiary (the collection of Doom
        // creatures); Zen levels reveal a calm guardian that isn't catalogued.
        let isDoom = library.seed(forID: level.id)?.theme == .doom
        if creatureRevealed, isDoom, state.bestiary[level.creatureID] == nil {
            state.bestiary[level.creatureID] = BestiaryEntry(
                creatureID: level.creatureID,
                firstRevealedLevelID: level.id
            )
            state.stats.creaturesRevealed = state.bestiary.count
        }

        // Serenity reward: base for a clear, more for a first-time clear.
        addSerenity(wasCleared ? 5 : 10)

        save()
    }

    /// Record a single found word into lifetime stats (longest word, pangrams,
    /// totals). Called per submission; `recordClear` handles the clear tally.
    func recordWord(_ word: String, isBonus: Bool, isPangram: Bool) {
        state.stats.recordWord(word, isBonus: isBonus, isPangram: isPangram)
        save()
    }

    /// Whole days since the Unix epoch in UTC. Monotonic and always positive.
    private static func utcDayNumber(now: Date = Date()) -> Int {
        Int(now.timeIntervalSince1970 / 86_400)
    }

    // MARK: - Store

    /// Mirror the StoreKit premium entitlement so ad gating works offline.
    func setPremium(_ on: Bool) {
        guard state.premiumUnlocked != on else { return }
        state.premiumUnlocked = on
        save()
    }

    /// Deliver a verified purchase. Consumables credit serenity exactly once
    /// per transaction id (StoreKit can replay unfinished transactions after a
    /// crash); the premium non-consumable flips the entitlement mirror.
    func creditPurchase(item: StoreItem, transactionID: UInt64) {
        guard let amount = item.serenityAmount else {
            setPremium(true)
            return
        }
        guard state.markTransactionProcessed(transactionID) else { return }
        addSerenity(amount)
    }

    // MARK: - Cosmetics (the Shrine)

    /// Buy a cosmetic with serenity. Owning it already counts as success;
    /// otherwise it succeeds only if the player can afford `cost`.
    @discardableResult
    func unlockCosmetic(id: String, cost: Int) -> Bool {
        if state.ownedCosmetics.contains(id) { return true }
        guard spendSerenity(cost) else { return false }
        state.ownedCosmetics.insert(id)
        save()
        return true
    }

    /// Equip an owned palette / poem set (nil = the built-in default).
    func equipPalette(_ id: String?) {
        guard id == nil || state.ownedCosmetics.contains(id!) else { return }
        state.equippedPalette = id
        save()
    }

    func equipPoemSet(_ id: String?) {
        guard id == nil || state.ownedCosmetics.contains(id!) else { return }
        state.equippedPoemSet = id
        save()
    }

    func addSerenity(_ amount: Int) {
        guard amount != 0 else { return }
        state.serenity = max(0, state.serenity + amount)
        save()
    }

    /// Spend serenity if affordable. Returns `false` (and changes nothing) when
    /// the player can't afford it.
    @discardableResult
    func spendSerenity(_ amount: Int) -> Bool {
        guard amount >= 0, state.serenity >= amount else { return false }
        state.serenity -= amount
        save()
        return true
    }

    // MARK: - Progression

    /// Whether `levelID` has ever been cleared.
    func isCleared(_ levelID: String) -> Bool {
        state.progress[levelID]?.cleared ?? false
    }

    /// Levels unlock linearly: order 0 is always open; every later level opens
    /// once the level immediately before it (by play order) has been cleared.
    func isUnlocked(_ levelID: String) -> Bool {
        guard let order = library.order(forID: levelID) else { return false }
        return order == 0 || isCleared(library.id(atOrder: order - 1))
    }

    /// The first level in play order the player has not yet cleared.
    var nextUnclearedLevelID: String? {
        var order = 0
        while order < 100_000 {            // safety bound; player can't clear ∞
            let id = library.id(atOrder: order)
            if !isCleared(id) { return id }
            order += 1
        }
        return nil
    }
}
