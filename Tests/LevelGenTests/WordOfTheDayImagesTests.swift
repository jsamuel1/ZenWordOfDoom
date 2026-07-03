import XCTest
import GameCore
@testable import LevelGen

final class WordOfTheDayImagesTests: XCTestCase {
    func testEverySlugListHasTwelveEntries() {
        XCTAssertEqual(WordOfTheDayImages.slugs(for: .zen).count, 12)
        XCTAssertEqual(WordOfTheDayImages.slugs(for: .doom).count, 12)
    }

    func testEverySlugIsUnique() {
        for theme in Theme.allCases {
            let slugs = WordOfTheDayImages.slugs(for: theme)
            XCTAssertEqual(Set(slugs).count, slugs.count, "\(theme) has duplicate slugs")
        }
    }

    /// Completeness: every curated word must map to one of its theme's own
    /// slugs. A word silently falling through to the wrong theme's slug (or
    /// no slug) would show mismatched or missing art for that day.
    func testEveryCuratedWordMapsToASlugOfItsOwnTheme() {
        for theme in Theme.allCases {
            let slugs = Set(WordOfTheDayImages.slugs(for: theme))
            for word in WordOfTheDay.words(for: theme) {
                let slug = WordOfTheDayImages.slug(forWord: word, theme: theme)
                XCTAssertTrue(slugs.contains(slug), "\(word) (\(theme)) mapped to unknown slug \(slug)")
            }
        }
    }

    /// Every slug should actually be used by at least one word — an unused
    /// slug is dead art we'd generate and ship for nothing.
    func testEverySlugIsUsedByAtLeastOneWord() {
        for theme in Theme.allCases {
            let used = Set(WordOfTheDay.words(for: theme).map { WordOfTheDayImages.slug(forWord: $0, theme: theme) })
            for slug in WordOfTheDayImages.slugs(for: theme) {
                XCTAssertTrue(used.contains(slug), "slug \(slug) (\(theme)) is never used")
            }
        }
    }
}
