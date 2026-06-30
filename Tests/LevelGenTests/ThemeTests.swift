import XCTest
@testable import LevelGen

final class ThemeTests: XCTestCase {
    func test_themes_areStableRawValues() {
        XCTAssertEqual(Theme.zen.rawValue, "zen")
        XCTAssertEqual(Theme.doom.rawValue, "doom")
        XCTAssertEqual(Theme.allCases.count, 2)
    }
}
