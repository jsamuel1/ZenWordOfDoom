import XCTest
@testable import GameCore

/// Minimal validator so GameCore tests stay independent of the real dictionary
/// validator (`SystemDictionary`/`UITextChecker`).
private struct StubValidator: WordValidating {
    let valid: Set<String>
    func isValidWord(_ word: String) -> Bool { valid.contains(word.uppercased()) }
}

final class DoomMultiplierTests: XCTestCase {
    private func doomEngine() -> GameEngine {
        let validator = StubValidator(valid: ["STONE", "NODE", "DOTS", "NOTE", "TENS"])
        return GameEngine(level: SampleLevel.make(), validator: validator, mode: .doom(timeLimit: 240))
    }

    private func zenEngine() -> GameEngine {
        let validator = StubValidator(valid: ["STONE", "NODE", "DOTS", "NOTE", "TENS"])
        return GameEngine(level: SampleLevel.make(), validator: validator, mode: .zen)
    }

    // MARK: Scoring.doomMultiplier tiers

    func testMultiplierTiersByRemainingFraction() {
        // > 2/3 remaining → 4x
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 240, timeLimit: 240), 4)
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 161, timeLimit: 240), 4)
        // > 1/3 remaining → 3x
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 160, timeLimit: 240), 3)
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 81, timeLimit: 240), 3)
        // any time left on the clock → 2x
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 80, timeLimit: 240), 2)
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 1, timeLimit: 240), 2)
        // expired → base points, never zero
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 0, timeLimit: 240), 1)
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: -5, timeLimit: 240), 1)
    }

    func testMultiplierTiersScaleWithTheLimit() {
        // Fractional thresholds, so the longer Reduced Doom limit behaves the same.
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 300, timeLimit: 360), 4)
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 180, timeLimit: 360), 3)
        XCTAssertEqual(Scoring.doomMultiplier(timeRemaining: 60, timeLimit: 360), 2)
    }

    // MARK: Engine multiplier application

    func testGridWordScoresMultiplied() {
        let e = doomEngine()
        e.setScoreMultiplier(4)
        _ = e.submit("STONE")
        XCTAssertEqual(e.score, Scoring.wordScore(length: 5, isPangram: false) * 4)
        XCTAssertTrue(e.solvedSlotIDs.contains(0))
    }

    func testBonusWordScoresMultiplied() {
        let e = doomEngine()
        e.setScoreMultiplier(3)
        let result = e.submit("NOTE")
        XCTAssertEqual(result, .bonusWord("NOTE"))
        XCTAssertEqual(e.score, Scoring.bonusScore(length: 4) * 3)
    }

    func testExpiryKeepsEarnedPointsAndScoresNewWordsAtBase() {
        let e = doomEngine()
        e.setScoreMultiplier(4)
        _ = e.submit("STONE")
        let scoreAtFourX = e.score
        XCTAssertGreaterThan(scoreAtFourX, 0)

        // Timer expiry: multiplier drops to 1, nothing is voided.
        e.setScoreMultiplier(1)
        _ = e.submit("NODE")
        XCTAssertEqual(
            e.score,
            scoreAtFourX + Scoring.wordScore(length: 4, isPangram: false),
            "post-expiry words earn base points; earned points are kept"
        )
        XCTAssertTrue(e.solvedSlotIDs.contains(1))
    }

    func testMultiplierClampsToAtLeastOne() {
        let e = doomEngine()
        e.setScoreMultiplier(0)
        XCTAssertEqual(e.scoreMultiplier, 1)
        _ = e.submit("STONE")
        XCTAssertEqual(e.score, Scoring.wordScore(length: 5, isPangram: false))
    }

    func testSetScoreMultiplierIsDoomOnly() {
        let e = zenEngine()
        e.setScoreMultiplier(4)
        XCTAssertEqual(e.scoreMultiplier, 1, "zen mode has no clock, so no bonus tiers")
        _ = e.submit("STONE")
        XCTAssertEqual(e.score, Scoring.wordScore(length: 5, isPangram: false))
    }

    func testExpiryStillAllowsCompletionAndStir() {
        let e = doomEngine()
        _ = e.submit("STONE")
        e.setScoreMultiplier(1)
        let stirAfterExpiry = e.stir

        _ = e.submit("NODE")
        _ = e.submit("DOTS")

        XCTAssertTrue(e.isComplete, "grid should be complete")
        XCTAssertEqual(e.stir, 1.0, accuracy: 0.0001, "stir should reach 1.0 on completion")
        XCTAssertGreaterThan(e.stir, stirAfterExpiry, "stir should bump even after expiry")
    }
}
