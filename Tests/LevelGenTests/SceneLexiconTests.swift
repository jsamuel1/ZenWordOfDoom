import XCTest
@testable import LevelGen

final class SceneLexiconTests: XCTestCase {
    func testEveryBundledSceneHasEnoughWords() {
        let lex = SceneLexicon.shared
        let slugs = ThemePools.zenDoom.scenes.values.flatMap { $0 }
        XCTAssertFalse(slugs.isEmpty)
        for slug in slugs {
            XCTAssertGreaterThanOrEqual(lex.words(for: slug).count, 12, "scene \(slug)")
        }
    }

    func testWordsAreUppercaseRealLetters() {
        for w in SceneLexicon.shared.words(for: "still-pond") {
            XCTAssertEqual(w, w.uppercased())
            XCTAssertTrue(w.allSatisfy(\.isLetter), "\(w) has non-letters")
        }
    }

    func testWordsAreDeduplicatedAndSorted() {
        let w = SceneLexicon.shared.words(for: "still-pond")
        XCTAssertEqual(w, w.sorted())
        XCTAssertEqual(Set(w).count, w.count)
    }

    func testUnknownSceneReturnsEmpty() {
        XCTAssertTrue(SceneLexicon.shared.words(for: "no-such-scene").isEmpty)
    }
}
