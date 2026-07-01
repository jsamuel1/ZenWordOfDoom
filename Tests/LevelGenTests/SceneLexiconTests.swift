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

    /// Every scene must offer a word of each wheel length 5...9 so scene-coupled
    /// anchors (and boss key words) work at every band, including expert/master.
    func testEverySceneCoversLengthsFiveToNine() {
        let lex = SceneLexicon.shared
        for slug in ThemePools.zenDoom.scenes.values.flatMap({ $0 }) {
            let lengths = Set(lex.words(for: slug).map(\.count))
            for n in 5...9 {
                XCTAssertTrue(lengths.contains(n), "scene \(slug) missing a length-\(n) word")
            }
        }
    }
}
