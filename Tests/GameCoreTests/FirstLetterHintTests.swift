import XCTest
@testable import GameCore

private struct AnyValid: WordValidating {
    func isValidWord(_ word: String) -> Bool { true }
}

final class FirstLetterHintTests: XCTestCase {
    func testRevealsFirstCellOfEverySlotWithoutSolving() {
        let level = SampleLevel.make()   // STONE / NODE / DOTS
        let e = GameEngine(level: level, validator: AnyValid())
        e.revealFirstLetters()
        for slot in level.slots {
            let firstCell = slot.cells.first!
            XCTAssertEqual(e.filledCells[firstCell], Array(slot.answer).first,
                           "first cell of \(slot.answer) should be revealed")
        }
        XCTAssertTrue(e.solvedSlotIDs.isEmpty, "revealing first letters must not solve slots")
        XCTAssertFalse(e.isComplete)
    }

    func testIsIdempotent() {
        let e = GameEngine(level: SampleLevel.make(), validator: AnyValid())
        e.revealFirstLetters()
        let after1 = e.filledCells
        e.revealFirstLetters()
        XCTAssertEqual(e.filledCells, after1)
    }

    func testNoOpOnBossLevel() {
        let boss = Level(id: "b", wheel: Wheel(letters: "STONED"), slots: [],
                         sceneID: "s", creatureID: "c", format: .pangramHunt(target: 3))
        let e = GameEngine(level: boss, validator: AnyValid())
        e.revealFirstLetters()
        XCTAssertTrue(e.filledCells.isEmpty)
    }
}
