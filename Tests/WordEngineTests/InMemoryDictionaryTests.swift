import XCTest
import GameCore
@testable import WordEngine

final class InMemoryDictionaryTests: XCTestCase {
    func testMembershipIsCaseInsensitive() {
        let dict = InMemoryDictionary(words: ["stone", "node"])
        XCTAssertTrue(dict.isValidWord("STONE"))
        XCTAssertTrue(dict.isValidWord("stone"))
        XCTAssertFalse(dict.isValidWord("STORM"))
    }

    func testBuildableFromWheel() {
        let dict = SampleWords.dictionary
        let words = dict.words(buildableFrom: LetterMultiset("STONED"), minLength: 3)
        XCTAssertTrue(words.contains("STONE"))
        XCTAssertTrue(words.contains("NODE"))
        XCTAssertTrue(words.contains("DOTS"))
        XCTAssertFalse(words.contains("CAT"), "C/A not on the STONED wheel")
        XCTAssertTrue(words.allSatisfy { $0.count >= 3 })
    }

    func testSampleLevelAnswersAreAllValidWords() {
        let dict = SampleWords.dictionary
        for slot in SampleLevel.make().slots {
            XCTAssertTrue(dict.isValidWord(slot.answer),
                          "sample answer \(slot.answer) must be in the dictionary")
        }
    }

    func testSampleGridHasNoConflictingCells() {
        // Every shared cell must agree across answers.
        var cells: [GridCoord: Character] = [:]
        for slot in SampleLevel.make().slots {
            for (offset, coord) in slot.cells.enumerated() {
                let ch = Array(slot.answer)[offset]
                if let existing = cells[coord] {
                    XCTAssertEqual(existing, ch, "conflict at \(coord)")
                }
                cells[coord] = ch
            }
        }
    }
}
