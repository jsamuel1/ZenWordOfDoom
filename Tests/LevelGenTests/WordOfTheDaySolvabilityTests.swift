import XCTest
import GameCore
@testable import LevelGen

/// Every curated Word-of-the-Day word must be *playable*: enough shorter
/// real words must be buildable from its letters to realistically reach its
/// Pangram-Hunt word-count target. This is the same invariant
/// `SolvabilitySweepTests` checks for procedurally generated levels, applied
/// to the hand-curated list instead — curation mistakes get caught here
/// rather than silently shipping an unwinnable bonus level.
final class WordOfTheDaySolvabilityTests: XCTestCase {
    func test_everyCuratedWordMeetsItsPangramTarget() {
        for theme in Theme.allCases {
            for word in WordOfTheDay.words(for: theme) {
                let multiset = LetterMultiset(Array(word))
                let target = PackCatalog.pangramTarget(for: DifficultyBand(wheelSize: word.count))
                let buildable = GeneralWordList.shared.buildableWords(from: multiset, minLength: GameEngine.minWordLength)
                // +1 because the pangram itself (the full word) counts toward
                // `foundWords`, but for words > 9 letters it can't appear in
                // the (3-9 letter) general corpus — don't double-require it.
                let effectiveCount = word.count <= 9 ? buildable.count : buildable.count + 1
                XCTAssertGreaterThanOrEqual(effectiveCount, target,
                    "\(word) (\(theme)): only \(buildable.count) buildable sub-words, needs \(target)")
            }
        }
    }
}
