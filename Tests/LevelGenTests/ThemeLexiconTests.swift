import XCTest
@testable import LevelGen

final class ThemeLexiconTests: XCTestCase {
    func test_lexiconsNonEmptyAndUppercase() {
        for theme in Theme.allCases {
            let words = ThemeLexicon.shared.words(for: theme)
            XCTAssertFalse(words.isEmpty, "\(theme) lexicon empty")
            for w in words { XCTAssertEqual(w, w.uppercased()) }
        }
    }

    func test_membershipIsCaseInsensitiveAndThemeScoped() {
        XCTAssertTrue(ThemeLexicon.shared.contains("GARDEN", theme: .zen))
        XCTAssertTrue(ThemeLexicon.shared.contains("garden", theme: .zen))
        XCTAssertFalse(ThemeLexicon.shared.contains("GARDEN", theme: .doom))
    }
}
