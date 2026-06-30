import XCTest
@testable import LevelGen

final class CommonWordsTests: XCTestCase {
    func test_loadsManyWords() {
        XCTAssertGreaterThan(CommonWords.shared.count, 1000)
    }

    func test_knowsCommonButNotObscureWords() {
        XCTAssertTrue(CommonWords.shared.contains("LIST"))
        XCTAssertTrue(CommonWords.shared.contains("STILL"))
        XCTAssertTrue(CommonWords.shared.contains("stone")) // case-insensitive
        XCTAssertFalse(CommonWords.shared.contains("LITS"))
        XCTAssertFalse(CommonWords.shared.contains("TILS"))
    }
}
