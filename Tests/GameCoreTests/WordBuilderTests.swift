import XCTest
@testable import GameCore

final class WordBuilderTests: XCTestCase {
    func testTapSequenceBuildsSelection() {
        let b = WordBuilder()
        XCTAssertNil(b.apply(.begin(tileID: 0)))
        XCTAssertNil(b.apply(.extend(tileID: 1)))
        XCTAssertNil(b.apply(.extend(tileID: 2)))
        XCTAssertEqual(b.selection, [0, 1, 2])
        XCTAssertEqual(b.apply(.submit), [0, 1, 2])
        XCTAssertEqual(b.selection, [], "submit clears selection")
    }

    func testReTappingLastTileDeselects() {
        let b = WordBuilder()
        b.apply(.begin(tileID: 5))
        b.apply(.extend(tileID: 6))
        b.apply(.extend(tileID: 6)) // tap same tile again removes it
        XCTAssertEqual(b.selection, [5])
    }

    func testBacktrackAndCancel() {
        let b = WordBuilder()
        b.apply(.begin(tileID: 1))
        b.apply(.extend(tileID: 2))
        b.apply(.backtrack)
        XCTAssertEqual(b.selection, [1])
        b.apply(.cancel)
        XCTAssertEqual(b.selection, [])
        XCTAssertNil(b.apply(.submit), "submitting empty selection yields nil")
    }

    func testCurrentWordResolvesFromWheel() {
        let wheel = Wheel(letters: "STONED")
        let b = WordBuilder()
        b.apply(.begin(tileID: 0)) // S
        b.apply(.extend(tileID: 1)) // T
        b.apply(.extend(tileID: 2)) // O
        b.apply(.extend(tileID: 3)) // N
        b.apply(.extend(tileID: 4)) // E
        XCTAssertEqual(b.currentWord(on: wheel), "STONE")
    }
}
