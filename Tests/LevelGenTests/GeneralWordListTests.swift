import XCTest
import GameCore
@testable import LevelGen

final class GeneralWordListTests: XCTestCase {
    func test_loadsLargeCorpus() {
        XCTAssertGreaterThan(GeneralWordList.shared.count, 50_000)
    }

    func test_buildableWordsAreBuildableAndIncludeKnownWords() {
        let multiset = LetterMultiset("GARDEN")
        let words = GeneralWordList.shared.buildableWords(from: multiset, minLength: 3)
        XCTAssertFalse(words.isEmpty)
        for w in words { XCTAssertTrue(multiset.canBuild(w), "\(w) not buildable from GARDEN") }
        XCTAssertTrue(words.contains("GARDEN"))
        XCTAssertTrue(words.contains("RANGE"))
    }

    func test_corpusContainsCommonNineLetterWord() {
        let multiset = LetterMultiset("MOONLIGHT")
        XCTAssertTrue(GeneralWordList.shared.buildableWords(from: multiset).contains("MOONLIGHT"))
    }
}
