import XCTest
import GameCore
@testable import LevelGen

final class DeterministicWordProviderTests: XCTestCase {
    func test_returnsOnlyBuildableCorpusWords() {
        let wheel = Wheel(letters: "GARDEN")
        let words = DeterministicWordProvider().words(forWheel: wheel, theme: .zen, limit: 50)
        XCTAssertFalse(words.isEmpty)
        let multiset = wheel.multiset
        for w in words { XCTAssertTrue(multiset.canBuild(w), "\(w) not buildable") }
    }

    func test_themeWordsRankFirst() {
        // GARDEN is a zen anchor and buildable from its own letters, so the
        // top-ranked result must be a zen-lexicon word.
        let wheel = Wheel(letters: "GARDEN")
        let words = DeterministicWordProvider().words(forWheel: wheel, theme: .zen, limit: 50)
        XCTAssertTrue(ThemeLexicon.shared.contains(words.first!, theme: .zen),
                      "top word \(words.first!) is not a zen anchor")
    }

    func test_isDeterministicAndRespectsLimit() {
        let wheel = Wheel(letters: "SHADOW")
        let p = DeterministicWordProvider()
        let a = p.words(forWheel: wheel, theme: .doom, limit: 5)
        let b = p.words(forWheel: wheel, theme: .doom, limit: 5)
        XCTAssertEqual(a, b)
        XCTAssertLessThanOrEqual(a.count, 5)
    }
}
