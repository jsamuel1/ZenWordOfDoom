import XCTest
import GameCore
import LevelGen
@testable import ZenWordOfDoom

@MainActor
final class GameStoreTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).json")
    }
    override func tearDown() { try? FileManager.default.removeItem(at: url); super.tearDown() }

    private func makeStore() -> GameStore { GameStore(fileURL: url) }

    func testClearRecordsProgressAndImprovesMonotonically() {
        let store = makeStore()
        let level = SampleLevel.make()
        store.recordClear(level: level, score: 100, bonusWords: 2, usedHint: false, creatureRevealed: true)
        store.recordClear(level: level, score: 40, bonusWords: 1, usedHint: true, creatureRevealed: false)
        let p = store.state.progress[level.id]!
        XCTAssertTrue(p.cleared)
        XCTAssertEqual(p.bestScore, 100)          // never regresses
        XCTAssertEqual(p.bonusWordsFound, 2)
        XCTAssertTrue(p.noHint)                   // once clean, stays clean
        // First clear (no hint) pays 8; the replay clear pays nothing.
        XCTAssertEqual(store.state.serenity, 8)
    }

    func testStreakAdvancesOnClearNotOnLoad() {
        let store = makeStore()
        XCTAssertEqual(store.state.stats.currentStreak, 0)   // opening ≠ playing
        store.recordClear(level: SampleLevel.make(), score: 10, bonusWords: 0,
                          usedHint: false, creatureRevealed: false)
        XCTAssertEqual(store.state.stats.currentStreak, 1)
    }

    func testSaveLoadRoundTrip() {
        let store = makeStore()
        store.addSerenity(42)
        store.recordClear(level: SampleLevel.make(), score: 5, bonusWords: 0,
                          usedHint: true, creatureRevealed: false)
        let reloaded = GameStore(fileURL: url)
        XCTAssertEqual(reloaded.state, store.state)
    }

    /// Schema v1 → v2: level content was regenerated wholesale, so migration
    /// clears per-level progress — and ONLY that. Purchases, currency,
    /// cosmetics, bestiary, and lifetime stats all survive.
    func testSchemaV1SaveMigratesByClearingProgressOnly() throws {
        // A pre-v2 save: no schemaVersion key, with progress and earnings.
        let legacy = """
        {"serenity": 33,
         "premiumUnlocked": true,
         "ownedCosmetics": ["palette-ember"],
         "equippedPalette": "palette-ember",
         "processedTransactionIDs": [7],
         "progress": {"zen-master-41": {"levelID": "zen-master-41", "cleared": true,
                      "bestScore": 500, "bonusWordsFound": 3, "noHint": true}},
         "bestiary": {"gloom-eye": {"creatureID": "gloom-eye",
                      "firstRevealedLevelID": "zen-master-41"}}}
        """
        try legacy.data(using: .utf8)!.write(to: url)

        let store = makeStore()
        XCTAssertEqual(store.state.schemaVersion, SaveState.currentSchemaVersion)
        XCTAssertTrue(store.state.progress.isEmpty, "old level progress must reset")
        XCTAssertEqual(store.state.serenity, 33)
        XCTAssertTrue(store.state.premiumUnlocked)
        XCTAssertEqual(store.state.ownedCosmetics, ["palette-ember"])
        XCTAssertEqual(store.state.equippedPalette, "palette-ember")
        XCTAssertEqual(store.state.processedTransactionIDs, [7])
        XCTAssertEqual(store.state.bestiary["gloom-eye"]?.creatureID, "gloom-eye")

        // The migration persists immediately: a second load is already v2
        // and does not re-migrate.
        let reloaded = GameStore(fileURL: url)
        XCTAssertEqual(reloaded.state, store.state)
    }

    func testCurrentSchemaSaveIsNotTouchedByMigration() {
        let store = makeStore()
        store.recordClear(level: SampleLevel.make(), score: 10, bonusWords: 0,
                          usedHint: false, creatureRevealed: false)
        let reloaded = GameStore(fileURL: url)
        XCTAssertFalse(reloaded.state.progress.isEmpty, "v2 progress must survive reload")
    }

    func testVoidedClearAwardsNoSerenityButStillProgresses() {
        let store = makeStore()
        let level = SampleLevel.make()
        store.recordClear(level: level, score: 0, bonusWords: 0,
                          usedHint: false, creatureRevealed: false, voided: true)
        XCTAssertEqual(store.state.serenity, 0)                // no reward when voided
        XCTAssertTrue(store.state.progress[level.id]!.cleared) // path still opens
        XCTAssertEqual(store.state.stats.currentStreak, 1)     // streak still advances
    }

    func testBonusWordPaysSerenityGridWordDoesNot() {
        let store = makeStore()
        store.recordWord("ZEN", isBonus: false, isPangram: false)
        XCTAssertEqual(store.state.serenity, 0)   // grid words pay nothing directly
        store.recordWord("GARDEN", isBonus: true, isPangram: false)
        XCTAssertEqual(store.state.serenity, 1)   // bonus words pay Economy.bonusWordReward
    }

    func testVoidedBonusWordPaysNoSerenityButStillCountsStats() {
        let store = makeStore()
        store.recordWord("GARDEN", isBonus: true, isPangram: false, voided: true)
        XCTAssertEqual(store.state.serenity, 0)                    // voided: no payout
        XCTAssertEqual(store.state.stats.totalBonusWords, 1)       // stats still tracked
    }

    func testDoomDailyClearRecordsBestiaryEntry() throws {
        let store = makeStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents(year: 2026, month: 7, day: 1)
        var doomID: String?
        for offset in 0..<14 {
            components.day = 1 + offset
            let date = calendar.date(from: components)!
            let id = DailyPuzzle.id(for: date, calendar: calendar)
            if DailyPuzzle.seed(forID: id)?.theme == .doom {
                doomID = id
                break
            }
        }
        guard let dailyID = doomID else {
            throw XCTSkip("No doom-themed daily id found in the probed date range")
        }
        let base = SampleLevel.make()
        let level = Level(id: dailyID, wheel: base.wheel, slots: base.slots,
                          sceneID: base.sceneID, creatureID: "daily-doom-creature")
        store.recordClear(level: level, score: 10, bonusWords: 0,
                          usedHint: false, creatureRevealed: true)
        XCTAssertNotNil(store.state.bestiary["daily-doom-creature"])
    }

    func testSpendSerenityGuards() {
        let store = makeStore()
        XCTAssertFalse(store.spendSerenity(5))
        store.addSerenity(5)
        XCTAssertTrue(store.spendSerenity(5))
        XCTAssertEqual(store.state.serenity, 0)
        XCTAssertFalse(store.spendSerenity(-1))
    }
}
