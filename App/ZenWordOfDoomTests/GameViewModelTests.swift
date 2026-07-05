import XCTest
import GameCore
@testable import ZenWordOfDoom

private struct AcceptAll: WordValidating {
    func isValidWord(_ word: String) -> Bool { true }
}

/// Records every announcement made by the view model, for asserting VoiceOver
/// behavior without a real accessibility runtime.
private final class SpyAnnouncer: AccessibilityAnnouncing {
    var messages: [String] = []
    func announce(_ message: String) { messages.append(message) }
}

@MainActor
final class GameViewModelTests: XCTestCase {
    private var tempFileURLs: [URL] = []
    private var defaultsSuiteNames: [String] = []

    override func tearDown() {
        for url in tempFileURLs { try? FileManager.default.removeItem(at: url) }
        tempFileURLs = []
        for name in defaultsSuiteNames { UserDefaults().removePersistentDomain(forName: name) }
        defaultsSuiteNames = []
        super.tearDown()
    }

    private func makeModel(doom: Bool = false, announcer: any AccessibilityAnnouncing = SpyAnnouncer()) -> (GameViewModel, GameStore) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vm-\(UUID().uuidString).json")
        tempFileURLs.append(url)
        let store = GameStore(fileURL: url)
        let suiteName = UUID().uuidString
        defaultsSuiteNames.append(suiteName)
        let settings = AppSettings(defaults: UserDefaults(suiteName: suiteName)!)
        settings.doomMode = doom
        settings.firstLetterHints = false
        let model = GameViewModel(level: SampleLevel.make(), validator: AcceptAll(),
                                  settings: settings, store: store, announcer: announcer)
        return (model, store)
    }

    private func solve(_ model: GameViewModel) {
        // Submit every grid answer directly through the spoken path (which
        // resolves tiles greedily) — deterministic and UI-free.
        for slot in model.level.slots {
            model.submitSpoken(slot.answer)
        }
    }

    func testCompletionProducesSummaryAndSerenity() {
        let (model, store) = makeModel()
        solve(model)
        XCTAssertTrue(model.isComplete)
        XCTAssertNotNil(model.clearSummary)
        XCTAssertGreaterThan(store.state.serenity, 0)
        XCTAssertEqual(model.stir, 1.0)
    }

    func testDoomExpiryDropsToBasePointsAndStillCompletes() {
        let (model, store) = makeModel(doom: true)
        XCTAssertEqual(model.scoreMultiplier, 4)             // full clock = top tier
        model.handleDoomExpiry()
        XCTAssertTrue(model.doomExpired)
        XCTAssertTrue(model.showDoomOverlay)
        XCTAssertEqual(model.scoreMultiplier, 1)             // bonus gone, not points
        model.continueWithoutPoints()
        XCTAssertFalse(model.showDoomOverlay)
        solve(model)
        XCTAssertTrue(model.isComplete)
        XCTAssertGreaterThan(model.score, 0)                 // base points still land
        XCTAssertEqual(model.clearSummary?.serenityEarned, 0) // serenity stays voided
        XCTAssertEqual(store.state.serenity, Economy.startingSerenity)
        XCTAssertTrue(store.isCleared(model.level.id))       // path still opens
    }

    func testDoomWordsScoreFourTimesAtFullClock() {
        let (model, _) = makeModel(doom: true)
        model.submitSpoken("STONE")   // grid answer, found with the whole clock left
        XCTAssertEqual(model.score, Scoring.wordScore(length: 5, isPangram: false) * 4)
    }

    func testDoomExpiryIsZenNoop() {
        let (model, _) = makeModel(doom: false)
        model.handleDoomExpiry()   // guarded: no doom clock outside doom mode
        XCTAssertFalse(model.doomExpired)
        solve(model)
        XCTAssertGreaterThan(model.score, 0)
    }

    // MARK: Accessibility announcements

    func testFoundWordAnnouncesTheWord() {
        let spy = SpyAnnouncer()
        let (model, _) = makeModel(announcer: spy)
        model.submitSpoken("STONE")
        XCTAssertTrue(spy.messages.contains { $0.contains("STONE") })
    }

    func testDoomExpiryAnnouncesOnce() {
        let spy = SpyAnnouncer()
        let (model, _) = makeModel(doom: true, announcer: spy)
        model.handleDoomExpiry()
        model.handleDoomExpiry()   // guarded: must not announce a second time
        XCTAssertEqual(spy.messages.filter { $0.contains("doom has claimed") }.count, 1)
    }

    func testCompletionAnnounces() {
        let spy = SpyAnnouncer()
        let (model, _) = makeModel(announcer: spy)
        solve(model)
        XCTAssertTrue(model.isComplete)
        XCTAssertTrue(spy.messages.contains("Level cleared"))
    }

    func testDoomTimerUrgencyThresholdsAnnounceOnceEach() {
        let spy = SpyAnnouncer()
        let (model, _) = makeModel(doom: true, announcer: spy)
        // Drive the countdown across all three thresholds without waiting on
        // the real repeating Timer: `debugSetDeadline` sets the countdown
        // target directly, and `tickTimer()` is exposed (not private) so the
        // test can invoke a single tick deterministically at each point.
        model.debugSetDeadline(Date().addingTimeInterval(29))
        model.tickTimer()
        model.debugSetDeadline(Date().addingTimeInterval(14))
        model.tickTimer()
        model.debugSetDeadline(Date().addingTimeInterval(4))
        model.tickTimer()
        // A second tick at the same threshold must not re-announce.
        model.tickTimer()

        XCTAssertEqual(spy.messages.filter { $0 == "30 seconds remaining" }.count, 1)
        XCTAssertEqual(spy.messages.filter { $0 == "15 seconds remaining" }.count, 1)
        XCTAssertEqual(spy.messages.filter { $0 == "5 seconds remaining" }.count, 1)
    }
}
