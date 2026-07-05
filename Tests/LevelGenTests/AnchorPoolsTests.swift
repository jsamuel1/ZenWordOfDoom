import XCTest
import GameCore
@testable import LevelGen

/// Guards the bundled `anchor-pools.json` artifact against drift from the
/// corpus it was generated from (`scripts/generate-anchor-pools.sh`). If the
/// corpus is regenerated without re-running the anchor script, these fail.
final class AnchorPoolsTests: XCTestCase {
    /// Mirrors the generation script's per-length minimum count of COMMON
    /// buildable words. Update together with the script.
    private static let floors = [5: 15, 6: 25, 7: 40, 8: 55, 9: 70]

    func testEveryLengthHasAPool() {
        for n in 5...9 {
            let pool = AnchorPools.shared.anchors(ofLength: n)
            XCTAssertFalse(pool.isEmpty, "no anchors bundled for length \(n)")
            XCTAssertLessThanOrEqual(pool.count, 250, "length \(n) exceeds the generation cap")
        }
    }

    func testAnchorsAreCorrectLengthCommonAndInCorpus() {
        for n in 5...9 {
            for anchor in AnchorPools.shared.anchors(ofLength: n) {
                XCTAssertEqual(anchor.count, n, "\(anchor) bundled under length \(n)")
                XCTAssertTrue(GeneralWordList.shared.contains(anchor),
                              "\(anchor) is not in the corpus — boss pangram would be rejected")
                XCTAssertTrue(CommonWords.shared.contains(anchor),
                              "\(anchor) is not a common word — boss pangram would be obscure")
            }
        }
    }

    func testAnchorsAreDistinctLetterMultisets() {
        for n in 5...9 {
            let signatures = AnchorPools.shared.anchors(ofLength: n).map { String($0.sorted()) }
            XCTAssertEqual(Set(signatures).count, signatures.count,
                           "length \(n) pool contains anagram duplicates (same wheel twice)")
        }
    }

    /// Spot-checks the quality floor on a deterministic sample (full
    /// verification is the generation script's job; scanning the corpus for
    /// all 1,250 anchors would dominate the suite's runtime).
    func testSampledAnchorsMeetTheirCommonPoolFloor() {
        for n in 5...9 {
            let pool = AnchorPools.shared.anchors(ofLength: n)
            let floor = Self.floors[n]!
            for anchor in stride(from: 0, to: pool.count, by: 25).map({ pool[$0] }) {
                let commonBuildable = GeneralWordList.shared
                    .buildableWords(from: LetterMultiset(anchor))
                    .filter { CommonWords.shared.contains($0) }
                XCTAssertGreaterThanOrEqual(
                    commonBuildable.count, floor,
                    "\(anchor) (len \(n)) builds only \(commonBuildable.count) common words; floor is \(floor)"
                )
            }
        }
    }
}
