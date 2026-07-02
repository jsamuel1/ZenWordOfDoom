import XCTest
@testable import GameCore

/// Minimal validator so GameCore tests stay independent of the real dictionary
/// validator (`SystemDictionary`/`UITextChecker`).
private struct StubValidator: WordValidating {
    let valid: Set<String>
    func isValidWord(_ word: String) -> Bool { valid.contains(word.uppercased()) }
}

final class DoomVoidTests: XCTestCase {
    private func doomEngine() -> GameEngine {
        let validator = StubValidator(valid: ["STONE", "NODE", "DOTS", "NOTE", "TENS"])
        return GameEngine(level: SampleLevel.make(), validator: validator, mode: .doom(timeLimit: 150))
    }

    private func zenEngine() -> GameEngine {
        let validator = StubValidator(valid: ["STONE", "NODE", "DOTS", "NOTE", "TENS"])
        return GameEngine(level: SampleLevel.make(), validator: validator, mode: .zen)
    }

    func testVoidScoreZeroesAndFreezesScore() {
        let e = doomEngine()
        // Submit a grid word to earn points
        _ = e.submit("STONE")
        let scoreAfterStone = e.score
        XCTAssertGreaterThan(scoreAfterStone, 0, "STONE should earn points")
        XCTAssertFalse(e.scoreVoided, "scoreVoided should start false")

        // Void the score
        e.voidScore()
        XCTAssertTrue(e.scoreVoided, "scoreVoided should be true after voidScore()")
        XCTAssertEqual(e.score, 0, "score should be 0 after voidScore()")

        // Submit another grid word and verify score stays 0
        _ = e.submit("NODE")
        XCTAssertEqual(e.score, 0, "score should stay 0 when voided")
        // But the slot should still fill
        XCTAssertTrue(e.solvedSlotIDs.contains(1))
    }

    func testVoidStillAllowsCompletionAndStir() {
        let e = doomEngine()
        // Submit and void
        _ = e.submit("STONE")
        e.voidScore()
        let stirAfterVoid = e.stir

        // Complete the grid: submit the remaining words
        _ = e.submit("NODE")
        _ = e.submit("DOTS")

        XCTAssertTrue(e.isComplete, "grid should be complete")
        XCTAssertEqual(e.stir, 1.0, accuracy: 0.0001, "stir should reach 1.0 on completion")
        XCTAssertGreaterThan(e.stir, stirAfterVoid, "stir should bump even after void")
        XCTAssertEqual(e.score, 0, "score should remain 0 while voided")
    }

    func testVoidScoreIsDoomOnly() {
        let e = zenEngine()
        _ = e.submit("STONE")
        let scoreBeforeVoid = e.score
        XCTAssertGreaterThan(scoreBeforeVoid, 0)

        e.voidScore()

        XCTAssertFalse(e.scoreVoided, "scoreVoided should remain false in zen mode")
        XCTAssertEqual(e.score, scoreBeforeVoid, "score should be unchanged in zen mode")
    }

    func testBonusWordsScoreZeroWhenVoided() {
        let e = doomEngine()
        // Void before submitting a bonus word
        e.voidScore()
        XCTAssertEqual(e.score, 0)

        // Submit a bonus word (valid but not in grid)
        let result = e.submit("NOTE")
        XCTAssertEqual(result, .bonusWord("NOTE"))
        XCTAssertEqual(e.bonusWords, ["NOTE"])
        XCTAssertEqual(e.score, 0, "bonus word should not earn points when voided")
    }
}
