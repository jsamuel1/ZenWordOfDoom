import XCTest
import GameCore
import WordEngine
@testable import LevelKit

final class LevelKitTests: XCTestCase {

    private let dictionary = SampleWords.dictionary

    func testAllLevelsLoad() {
        let levels = LevelLibrary.allLevels()
        XCTAssertFalse(levels.isEmpty, "expected bundled levels to load")
        XCTAssertGreaterThanOrEqual(levels.count, 6, "contract requires 6-9 levels")
        XCTAssertLessThanOrEqual(levels.count, 9, "contract requires 6-9 levels")
    }

    func testWheelSizesInRange() {
        for level in LevelLibrary.allLevels() {
            XCTAssertGreaterThanOrEqual(level.wheel.size, 5, "\(level.id) wheel too small")
            XCTAssertLessThanOrEqual(level.wheel.size, 7, "\(level.id) wheel too large")
        }
    }

    func testEveryLevelIsValid() {
        for level in LevelLibrary.allLevels() {
            let problems = LevelValidator.problems(in: level, dictionary: dictionary)
            XCTAssertTrue(
                problems.isEmpty,
                "level \(level.id) has problems: \(problems.joined(separator: "; "))"
            )
        }
    }

    func testLevelLookupByID() {
        let ids = LevelLibrary.orderedLevelIDs()
        for id in ids {
            XCTAssertNotNil(LevelLibrary.level(id: id), "level(id:) failed for \(id)")
        }
        XCTAssertNil(LevelLibrary.level(id: "does-not-exist"))
    }

    func testNextLevelChainCoversAll() {
        let order = LevelLibrary.orderedLevelIDs()
        XCTAssertFalse(order.isEmpty)
        XCTAssertEqual(order.count, Set(order).count, "ordered IDs must be unique")

        // Walk the chain from the first level and confirm it visits all in order.
        var visited: [String] = []
        var current: String? = order.first
        while let id = current {
            visited.append(id)
            current = LevelLibrary.nextLevelID(after: id)
        }
        XCTAssertEqual(visited, order, "nextLevelID chain must cover every level in order")

        // The final level has no successor.
        XCTAssertNil(LevelLibrary.nextLevelID(after: order.last!))
    }

    func testPacksReferenceRealLevels() {
        let packs = LevelLibrary.packs()
        XCTAssertFalse(packs.isEmpty)
        for pack in packs {
            XCTAssertFalse(pack.levelIDs.isEmpty, "pack \(pack.id) has no levels")
            for id in pack.levelIDs {
                XCTAssertNotNil(LevelLibrary.level(id: id), "pack \(pack.id) references missing level \(id)")
            }
        }
    }

    func testCutScenesExistAndAreNonEmpty() {
        // Every level except the last should have a breath shown before the next.
        let order = LevelLibrary.orderedLevelIDs()
        for id in order where LevelLibrary.nextLevelID(after: id) != nil {
            guard let cut = LevelLibrary.cutScene(afterLevelID: id) else {
                XCTFail("missing cut scene after \(id)")
                continue
            }
            XCTAssertFalse(cut.poem.isEmpty, "cut scene \(id) has empty poem")
            XCTAssertTrue(cut.poem.allSatisfy { !$0.isEmpty }, "cut scene \(id) has empty poem line")
            XCTAssertGreaterThan(cut.popoutDelay, 0, "cut scene \(id) popoutDelay must be positive")
        }
    }

    func testDecodeLevelsFromData() throws {
        let json = """
        [
          {
            "id": "t1",
            "band": "easy",
            "wheel": ["S", "T", "O", "N", "E"],
            "scene": "test-scene",
            "creature": "test-creature",
            "slots": [
              { "id": 0, "answer": "STONE", "row": 0, "col": 0, "dir": "across" }
            ]
          }
        ]
        """.data(using: .utf8)!
        let decoded = try LevelLibrary.decodeLevels(from: json)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.id, "t1")
        let level = decoded.first!.toLevel()
        XCTAssertEqual(level.wheel.size, 5)
        XCTAssertEqual(level.slots.first?.answer, "STONE")
        XCTAssertEqual(level.slots.first?.direction, .across)
    }

    func testValidatorCatchesConflict() {
        // Two answers crossing with a conflicting shared cell.
        let level = Level(
            id: "bad",
            wheel: Wheel(letters: "STONED"),
            slots: [
                GridSlot(id: 0, answer: "STONE", origin: GridCoord(row: 0, col: 0), direction: .across),
                // DOTS down starting at (0,0) would put D where STONE has S.
                GridSlot(id: 1, answer: "DOTS", origin: GridCoord(row: 0, col: 0), direction: .down),
            ],
            sceneID: "x",
            creatureID: "y"
        )
        let problems = LevelValidator.problems(in: level, dictionary: dictionary)
        XCTAssertTrue(problems.contains { $0.contains("conflict") }, "expected a conflict problem, got \(problems)")
    }
}
