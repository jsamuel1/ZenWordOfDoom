import XCTest
import GameCore
@testable import LevelGen

final class DeterministicWordProviderTests: XCTestCase {
    func test_returnsOnlyBuildableCorpusWords() async throws {
        let wheel = Wheel(letters: "GARDEN")
        let words = try await DeterministicWordProvider().words(forWheel: wheel, theme: .zen, limit: 50)
        XCTAssertFalse(words.isEmpty)
        let multiset = wheel.multiset
        for w in words { XCTAssertTrue(multiset.canBuild(w), "\(w) not buildable") }
    }

    func test_themeWordsRankFirst() async throws {
        // GARDEN is a zen anchor and buildable from its own letters, so the
        // top-ranked result must be a zen-lexicon word.
        let wheel = Wheel(letters: "GARDEN")
        let words = try await DeterministicWordProvider().words(forWheel: wheel, theme: .zen, limit: 50)
        XCTAssertTrue(ThemeLexicon.shared.contains(words.first!, theme: .zen),
                      "top word \(words.first!) is not a zen anchor")
    }

    func test_commonWordsRankBeforeObscureOnes() async throws {
        // Neither LIST nor SILT is a zen anchor, but LIST is a common word and
        // SILT is not, so LIST must rank ahead.
        let wheel = Wheel(letters: "STILL")
        let words = try await DeterministicWordProvider().words(forWheel: wheel, theme: .zen, limit: 200)
        let iList = words.firstIndex(of: "LIST")
        let iSilt = words.firstIndex(of: "SILT")
        XCTAssertNotNil(iList, "LIST should be buildable & present")
        XCTAssertNotNil(iSilt, "SILT should be buildable & present")
        if let a = iList, let b = iSilt {
            XCTAssertLessThan(a, b, "common LIST should rank before obscure SILT")
        }
    }

    func test_isDeterministicAndRespectsLimit() async throws {
        let wheel = Wheel(letters: "SHADOW")
        let p = DeterministicWordProvider()
        let a = try await p.words(forWheel: wheel, theme: .doom, limit: 5)
        let b = try await p.words(forWheel: wheel, theme: .doom, limit: 5)
        XCTAssertEqual(a, b)
        XCTAssertLessThanOrEqual(a.count, 5)
    }
}
