import XCTest
import GameCore
@testable import ZenWordOfDoom

private struct AcceptAll: WordValidating {
    func isValidWord(_ word: String) -> Bool { true }
}

@MainActor
final class GameViewModelTests: XCTestCase {
    private func makeModel(doom: Bool = false) -> (GameViewModel, GameStore) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vm-\(UUID().uuidString).json")
        let store = GameStore(fileURL: url)
        let settings = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        settings.doomMode = doom
        settings.firstLetterHints = false
        let model = GameViewModel(level: SampleLevel.make(), validator: AcceptAll(),
                                  settings: settings, store: store)
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

    func testDoomExpiryVoidsAndStillCompletes() {
        let (model, store) = makeModel(doom: true)
        model.handleDoomExpiry()
        XCTAssertTrue(model.doomExpired)
        XCTAssertTrue(model.showDoomOverlay)
        model.continueWithoutPoints()
        XCTAssertFalse(model.showDoomOverlay)
        solve(model)
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.score, 0)                       // points forfeit
        XCTAssertEqual(model.clearSummary?.serenityEarned, 0)
        XCTAssertEqual(store.state.serenity, 0)
        XCTAssertTrue(store.isCleared(model.level.id))       // path still opens
    }

    func testDoomExpiryIsZenNoop() {
        let (model, _) = makeModel(doom: false)
        model.handleDoomExpiry()   // engine refuses the void outside doom
        XCTAssertFalse(model.doomExpired)
        solve(model)
        XCTAssertGreaterThan(model.score, 0)
    }
}
