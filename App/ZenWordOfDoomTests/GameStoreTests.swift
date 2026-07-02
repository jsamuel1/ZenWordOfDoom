import XCTest
import GameCore
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

    func testSpendSerenityGuards() {
        let store = makeStore()
        XCTAssertFalse(store.spendSerenity(5))
        store.addSerenity(5)
        XCTAssertTrue(store.spendSerenity(5))
        XCTAssertEqual(store.state.serenity, 0)
        XCTAssertFalse(store.spendSerenity(-1))
    }
}
