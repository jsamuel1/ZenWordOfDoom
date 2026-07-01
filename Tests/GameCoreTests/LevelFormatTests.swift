import XCTest
@testable import GameCore

/// Accepts a fixed set of words; keeps these tests independent of WordEngine.
private struct Stub: WordValidating {
    let valid: Set<String>
    func isValidWord(_ word: String) -> Bool { valid.contains(word.uppercased()) }
}

final class LevelFormatTests: XCTestCase {
    // MARK: LevelFormat / Level.format

    func testLevelDefaultsToCrossword() {
        let l = Level(id: "x", wheel: Wheel(letters: "STONED"), slots: [],
                      sceneID: "s", creatureID: "c")
        XCTAssertEqual(l.format, .crossword)
    }

    func testPangramHuntTargetStored() {
        let l = Level(id: "x", wheel: Wheel(letters: "STONED"), slots: [],
                      sceneID: "s", creatureID: "c", format: .pangramHunt(target: 6))
        XCTAssertEqual(l.format, .pangramHunt(target: 6))
    }

    // MARK: Pangram-hunt completion

    private func bossEngine(target: Int) -> GameEngine {
        let level = Level(id: "b", wheel: Wheel(letters: "STONED"), slots: [],
                          sceneID: "s", creatureID: "c", format: .pangramHunt(target: target))
        return GameEngine(level: level,
                          validator: Stub(valid: ["STONE", "NODE", "NODES", "STONED"]))
    }

    func testPangramHuntIncompleteWithoutPangram() {
        let e = bossEngine(target: 2)
        _ = e.submit("STONE")   // 5 letters, not a pangram
        _ = e.submit("NODES")   // 5 letters, not a pangram
        XCTAssertFalse(e.isComplete)
    }

    func testPangramHuntIncompleteBelowTarget() {
        let e = bossEngine(target: 2)
        _ = e.submit("STONED")  // pangram, but only 1 word
        XCTAssertFalse(e.isComplete)
    }

    func testPangramHuntCompleteWithPangramAndTarget() {
        let e = bossEngine(target: 2)
        _ = e.submit("NODE")    // valid word
        _ = e.submit("STONED")  // pangram
        XCTAssertTrue(e.isComplete)
    }

    func testPangramHuntSnapsStirToFullOnCompletion() {
        let e = bossEngine(target: 1)
        _ = e.submit("STONED")  // pangram => complete
        XCTAssertTrue(e.isComplete)
        XCTAssertEqual(e.stir, 1, accuracy: 0.0001, "completion must force the full reveal")
    }

    func testPangramHuntCreditsPangramBonus() {
        let e = bossEngine(target: 1)
        _ = e.submit("STONED")  // 6-letter pangram
        XCTAssertEqual(e.score, Scoring.wordScore(length: 6, isPangram: true),
                       "boss pangram must earn the pangram bonus, not the bonus-word score")
    }

    func testPangramHuntProgressReflectsWordsFound() {
        let e = bossEngine(target: 4)
        XCTAssertEqual(e.progress, 0, accuracy: 0.0001)
        _ = e.submit("NODE")
        XCTAssertEqual(e.progress, 0.25, accuracy: 0.0001)
        XCTAssertLessThan(e.stir, 1)
    }
}
