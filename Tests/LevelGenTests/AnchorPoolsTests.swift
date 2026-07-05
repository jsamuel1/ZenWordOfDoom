import XCTest
import GameCore
@testable import LevelGen

/// Guards the bundled `anchor-pools.json` artifact against drift from the
/// corpus it was generated from (`scripts/generate-anchor-pools.sh`). If the
/// corpus is regenerated without re-running the anchor script, these fail.
final class AnchorPoolsTests: XCTestCase {
    /// Mirrors the generation script's per-(length, tier) minimum count of
    /// COMMON buildable words. Update together with the script.
    private static let floors: [DifficultyTier: [Int: Int]] = [
        .easy:   [5: 20, 6: 35, 7: 60, 8: 90, 9: 120],
        .medium: [5: 14, 6: 22, 7: 38, 8: 55, 9: 75],
        .hard:   [5: 9, 6: 14, 7: 24, 8: 34, 9: 45],
    ]

    func testEveryLengthAndTierHasAPool() {
        for n in 5...9 {
            for tier in DifficultyTier.allCases {
                let pool = AnchorPools.shared.anchors(ofLength: n, tier: tier)
                XCTAssertFalse(pool.isEmpty, "no anchors bundled for length \(n) \(tier)")
                XCTAssertLessThanOrEqual(pool.count, 200, "length \(n) \(tier) exceeds the generation cap")
            }
        }
    }

    func testAnchorsAreCorrectLengthCommonSaneAndInCorpus() {
        let vowels = Set("AEIOU")
        for n in 5...9 {
            for anchor in AnchorPools.shared.anchors(ofLength: n) {
                XCTAssertEqual(anchor.count, n, "\(anchor) bundled under length \(n)")
                XCTAssertTrue(GeneralWordList.shared.contains(anchor),
                              "\(anchor) is not in the corpus — boss pangram would be rejected")
                XCTAssertTrue(CommonWords.shared.contains(anchor),
                              "\(anchor) is not a common word — boss pangram would be obscure")
                // Sanity gates: a vowel, >= 3 distinct letters, no letter x3.
                XCTAssertTrue(anchor.contains(where: { vowels.contains($0) }), "\(anchor) has no vowel")
                let counts = Dictionary(anchor.map { ($0, 1) }, uniquingKeysWith: +)
                XCTAssertGreaterThanOrEqual(counts.count, 3, "\(anchor) has < 3 distinct letters")
                XCTAssertLessThanOrEqual(counts.values.max() ?? 0, 2, "\(anchor) repeats a letter 3+ times")
            }
        }
    }

    func testAnchorsAreDistinctLetterMultisetsAcrossAllTiers() {
        for n in 5...9 {
            let signatures = AnchorPools.shared.anchors(ofLength: n).map { String($0.sorted()) }
            XCTAssertEqual(Set(signatures).count, signatures.count,
                           "length \(n) pools contain anagram duplicates (same wheel twice)")
        }
    }

    /// Spot-checks each tier's quality floor on a deterministic sample (full
    /// verification is the generation script's job; scanning the corpus for
    /// all ~3,000 anchors would dominate the suite's runtime).
    func testSampledAnchorsMeetTheirTierFloor() {
        for n in 5...9 {
            for tier in DifficultyTier.allCases {
                let pool = AnchorPools.shared.anchors(ofLength: n, tier: tier)
                let floor = Self.floors[tier]![n]!
                for anchor in stride(from: 0, to: pool.count, by: 40).map({ pool[$0] }) {
                    let commonBuildable = GeneralWordList.shared
                        .buildableWords(from: LetterMultiset(anchor))
                        .filter { CommonWords.shared.contains($0) }
                    XCTAssertGreaterThanOrEqual(
                        commonBuildable.count, floor,
                        "\(anchor) (len \(n), \(tier)) builds only \(commonBuildable.count) common words; floor is \(floor)"
                    )
                }
            }
        }
    }
}
