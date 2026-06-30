import XCTest
import GameCore
@testable import LevelGen

final class CrosswordLayoutEngineTests: XCTestCase {
    func test_allCrossingsAgree_andCoordsNonNegative() {
        let words = ["GARDEN", "RANGE", "DEAR", "READ", "GEAR", "DEAN", "NEAR"]
        let slots = CrosswordLayoutEngine().layout(words: words, maxSlots: 6, seed: 42)
        XCTAssertFalse(slots.isEmpty)
        var m: [GridCoord: Character] = [:]
        for slot in slots {
            let chars = Array(slot.answer)
            for (i, cell) in slot.cells.enumerated() {
                if let existing = m[cell] {
                    XCTAssertEqual(existing, chars[i], "conflict at \(cell)")
                } else {
                    m[cell] = chars[i]
                }
                XCTAssertGreaterThanOrEqual(cell.row, 0)
                XCTAssertGreaterThanOrEqual(cell.col, 0)
            }
        }
    }

    func test_isConnected() {
        let words = ["GARDEN", "RANGE", "DEAR", "READ", "GEAR"]
        let slots = CrosswordLayoutEngine().layout(words: words, maxSlots: 5, seed: 1)
        let maps = slots.map { Set($0.cells) }
        for (i, cells) in maps.enumerated() where slots.count > 1 {
            let others = maps.enumerated().filter { $0.offset != i }.map(\.element)
            XCTAssertTrue(others.contains { !$0.isDisjoint(with: cells) }, "slot \(i) disconnected")
        }
    }

    func test_isDeterministic() {
        let words = ["SHADOW", "SHADE", "HEADS", "AHEAD", "HATE"]
        let a = CrosswordLayoutEngine().layout(words: words, maxSlots: 5, seed: 7)
        let b = CrosswordLayoutEngine().layout(words: words, maxSlots: 5, seed: 7)
        XCTAssertEqual(a.map { [$0.answer, "\($0.origin.row),\($0.origin.col)", $0.direction.rawValue] },
                       b.map { [$0.answer, "\($0.origin.row),\($0.origin.col)", $0.direction.rawValue] })
    }
}
