import XCTest
import GameCore
import LevelGen
@testable import ZenWordOfDoom

/// Validates every curated Word-of-the-Day word against the real system
/// dictionary (`UITextChecker`, via `SystemDictionary`) — the exact
/// validator `GameEngine.submit` uses at runtime. This is the authoritative
/// "is it real" check for the 10-letter words, which the pure-package
/// `GeneralWordList` can't check (it's filtered to 3-9 letters).
final class WordOfTheDayDictionaryTests: XCTestCase {
    func testEveryCuratedWordIsARealDictionaryWord() {
        let dictionary = SystemDictionary()
        for theme in Theme.allCases {
            for word in WordOfTheDay.words(for: theme) {
                XCTAssertTrue(dictionary.isValidWord(word), "\(word) (\(theme)) failed system dictionary check")
            }
        }
    }
}
