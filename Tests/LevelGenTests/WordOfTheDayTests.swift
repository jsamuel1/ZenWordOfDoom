import XCTest
import GameCore
@testable import LevelGen

final class WordOfTheDayTests: XCTestCase {
    func testListsLoadAndAreNonEmpty() {
        XCTAssertEqual(WordOfTheDay.words(for: .zen).count, 77)
        XCTAssertEqual(WordOfTheDay.words(for: .doom).count, 61)
    }

    func testEveryWordIsEightToTenLettersUppercaseAndUnique() {
        for theme in Theme.allCases {
            let words = WordOfTheDay.words(for: theme)
            XCTAssertEqual(Set(words).count, words.count, "\(theme) list has duplicates")
            for word in words {
                XCTAssertTrue((8...10).contains(word.count), "\(word) is \(word.count) letters")
                XCTAssertEqual(word, word.uppercased(), "\(word) is not uppercase")
                XCTAssertTrue(word.allSatisfy { $0.isLetter }, "\(word) has non-letter characters")
            }
        }
    }

    func testNoWordAppearsInBothThemes() {
        let overlap = Set(WordOfTheDay.words(for: .zen)).intersection(WordOfTheDay.words(for: .doom))
        XCTAssertTrue(overlap.isEmpty, "words shared across themes: \(overlap)")
    }

    /// 8-9 letter curated words must be real dictionary entries; the bundled
    /// corpus itself is the project's existing ground truth for "real word"
    /// (it's what generation validates every other word against). 10-letter
    /// words are skipped here — the corpus is filtered to 3-9 letters, so it
    /// structurally cannot contain them; those are validated against the
    /// live system dictionary instead (see WordOfTheDayImagesTests in the
    /// app target, which has UITextChecker access).
    func testEightAndNineLetterWordsAreInGeneralCorpus() {
        for theme in Theme.allCases {
            for word in WordOfTheDay.words(for: theme) where word.count <= 9 {
                XCTAssertTrue(GeneralWordList.shared.contains(word),
                              "\(word) (\(theme)) not found in the general corpus")
            }
        }
    }

    func testWordIsDeterministicForSameThemeAndDay() {
        let a = WordOfTheDay.word(forTheme: .zen, dayNumber: 100)
        let b = WordOfTheDay.word(forTheme: .zen, dayNumber: 100)
        XCTAssertEqual(a, b)
    }

    func testWordVariesAcrossDifferentDays() {
        let a = WordOfTheDay.word(forTheme: .zen, dayNumber: 0)
        let b = WordOfTheDay.word(forTheme: .zen, dayNumber: 1)
        XCTAssertNotEqual(a, b)
    }

    func testNoRepeatWithinACycle() {
        for theme in Theme.allCases {
            let cycleLength = WordOfTheDay.words(for: theme).count
            let words = (0..<cycleLength).map { WordOfTheDay.word(forTheme: theme, dayNumber: $0) }
            XCTAssertEqual(Set(words).count, cycleLength, "\(theme) repeated a word within one cycle")
        }
    }

    func testReshufflesDifferentlyAcrossCycles() {
        let cycleLength = WordOfTheDay.words(for: .zen).count
        let firstCycle = (0..<cycleLength).map { WordOfTheDay.word(forTheme: .zen, dayNumber: $0) }
        let secondCycle = (0..<cycleLength).map { WordOfTheDay.word(forTheme: .zen, dayNumber: cycleLength + $0) }
        XCTAssertNotEqual(firstCycle, secondCycle, "second cycle used the same order as the first")
        // Still the same *set* of words, just reordered.
        XCTAssertEqual(Set(firstCycle), Set(secondCycle))
    }

    func testEveryReturnedWordIsFromTheThemesList() {
        let zenSet = Set(WordOfTheDay.words(for: .zen))
        for day in 0..<200 {
            XCTAssertTrue(zenSet.contains(WordOfTheDay.word(forTheme: .zen, dayNumber: day)))
        }
    }
}
