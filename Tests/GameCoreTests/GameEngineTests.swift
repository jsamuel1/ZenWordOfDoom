import XCTest
@testable import GameCore

/// Minimal validator so GameCore tests stay independent of WordEngine.
private struct StubValidator: WordValidating {
    let valid: Set<String>
    func isValidWord(_ word: String) -> Bool { valid.contains(word.uppercased()) }
}

final class GameEngineTests: XCTestCase {
    private func engine() -> GameEngine {
        let validator = StubValidator(valid: ["STONE", "NODE", "DOTS", "NOTE", "TENS"])
        return GameEngine(level: SampleLevel.make(), validator: validator)
    }

    func testLetterMultisetBuildability() {
        let ms = LetterMultiset("STONED")
        XCTAssertTrue(ms.canBuild("STONE"))
        XCTAssertTrue(ms.canBuild("NODE"))
        XCTAssertFalse(ms.canBuild("STEED"), "only one E available")
        XCTAssertFalse(ms.canBuild("CAT"), "letters not on wheel")
    }

    func testRejectsTooShort() {
        XCTAssertEqual(engine().submit("ON"), .invalid(.tooShort))
    }

    func testRejectsNotBuildable() {
        XCTAssertEqual(engine().submit("CATS"), .invalid(.notBuildable))
    }

    func testRejectsNotInDictionary() {
        // TOED is buildable from STONED but not in the stub's valid set.
        XCTAssertEqual(engine().submit("TOED"), .invalid(.notInDictionary))
    }

    func testFillsMatchingSlot() {
        let e = engine()
        XCTAssertEqual(e.submit("STONE"), .filledSlots([0]))
        XCTAssertTrue(e.solvedSlotIDs.contains(0))
        XCTAssertEqual(e.filledCells[GridCoord(row: 0, col: 0)], "S")
        XCTAssertEqual(e.filledCells[GridCoord(row: 0, col: 4)], "E")
    }

    func testBonusWordDoesNotFillGrid() {
        let e = engine()
        let result = e.submit("NOTE") // valid, buildable, not a grid answer
        XCTAssertEqual(result, .bonusWord("NOTE"))
        XCTAssertEqual(e.bonusWords, ["NOTE"])
        XCTAssertTrue(e.solvedSlotIDs.isEmpty)
    }

    func testDuplicateSubmissionRejected() {
        let e = engine()
        XCTAssertEqual(e.submit("STONE"), .filledSlots([0]))
        XCTAssertEqual(e.submit("STONE"), .invalid(.alreadyFound))
    }

    func testCompletingAllSlotsWinsAndMaxesStir() {
        let e = engine()
        _ = e.submit("STONE")
        _ = e.submit("NODE")
        XCTAssertFalse(e.isComplete)
        _ = e.submit("DOTS")
        XCTAssertTrue(e.isComplete)
        XCTAssertEqual(e.progress, 1.0, accuracy: 0.0001)
        XCTAssertEqual(e.stir, 1.0, accuracy: 0.0001)
        // shared cells consistent
        XCTAssertEqual(e.filledCells[GridCoord(row: 0, col: 3)], "N")
        XCTAssertEqual(e.filledCells[GridCoord(row: 2, col: 3)], "D")
    }
}
