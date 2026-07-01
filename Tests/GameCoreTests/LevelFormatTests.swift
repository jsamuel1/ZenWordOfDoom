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
}
