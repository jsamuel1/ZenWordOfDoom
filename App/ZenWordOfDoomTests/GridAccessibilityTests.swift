import XCTest
import GameCore
@testable import ZenWordOfDoom

/// Covers `GridView.slotDescription`, the per-slot VoiceOver description used
/// by the crossword grid's accessibility subtree (audit 2.1).
///
/// Layout from `SampleLevel.make()`:
///   STONE across @ (0,0), id 0
///   NODE  down   @ (0,3), id 1
///   DOTS  across @ (2,3), id 2
final class GridAccessibilityTests: XCTestCase {
    private let level = SampleLevel.make()

    private func slot(_ id: Int) -> GridSlot {
        level.slots.first { $0.id == id }!
    }

    func testSolvedSlotDescribesFullAnswer() {
        let view = GridView(level: level, filledCells: [:], solvedSlotIDs: [0])
        XCTAssertEqual(view.slotDescription(slot(0)), "5-letter word, across — solved: STONE")
    }

    func testPartiallyRevealedSlotListsLettersAndBlanks() {
        // NODE is down @ (0,3): cells (0,3) N, (1,3) O, (2,3) D, (3,3) E.
        // Reveal the first and last letters only.
        let filled: [GridCoord: Character] = [
            GridCoord(row: 0, col: 3): "S",
            GridCoord(row: 3, col: 3): "E",
        ]
        let view = GridView(level: level, filledCells: filled, solvedSlotIDs: [])
        XCTAssertEqual(view.slotDescription(slot(1)), "4-letter word, down — S, blank, blank, E")
    }

    func testUntouchedSlotHasNoLettersRevealed() {
        let view = GridView(level: level, filledCells: [:], solvedSlotIDs: [])
        XCTAssertEqual(view.slotDescription(slot(2)), "4-letter word, across — no letters revealed")
    }

    func testUntouchedSlotIgnoresFillsBelongingToOtherSlots() {
        // Fills that belong only to slot 0 (STONE) shouldn't leak into slot 2's
        // (DOTS) description — the two slots don't share any cells.
        let filled: [GridCoord: Character] = [GridCoord(row: 0, col: 0): "S"]
        let view = GridView(level: level, filledCells: filled, solvedSlotIDs: [])
        XCTAssertEqual(view.slotDescription(slot(2)), "4-letter word, across — no letters revealed")
    }
}
