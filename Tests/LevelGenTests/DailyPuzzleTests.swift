import XCTest
import GameCore
@testable import LevelGen

final class DailyPuzzleTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"),
                                      year: y, month: m, day: d, hour: 12))!
    }

    func testIDFormat() {
        var utcCal = cal; utcCal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(DailyPuzzle.id(for: date(2026, 7, 2), calendar: utcCal),
                       "daily-2026-07-02")
    }

    func testSeedIsDeterministicAndDateSensitive() {
        let a = DailyPuzzle.seed(forID: "daily-2026-07-02")
        let b = DailyPuzzle.seed(forID: "daily-2026-07-02")
        let c = DailyPuzzle.seed(forID: "daily-2026-07-03")
        XCTAssertNotNil(a)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testSeedBandIsMidgame() {
        for day in 1...28 {
            let seed = DailyPuzzle.seed(forID: String(format: "daily-2026-07-%02d", day))!
            XCTAssertTrue([.medium, .hard, .expert].contains(seed.band))
        }
    }

    func testRejectsGarbage() {
        XCTAssertNil(DailyPuzzle.seed(forID: "daily-not-a-date"))
        XCTAssertNil(DailyPuzzle.seed(forID: "zen-easy-0"))
    }

    func testDailyLevelGenerates() async throws {
        let gen = ProceduralGenerator(
            wordProvider: DeterministicWordProvider(), pools: .zenDoom)
        for day in ["daily-2026-07-02", "daily-2026-12-25", "daily-2027-01-01"] {
            let seed = DailyPuzzle.seed(forID: day)!
            _ = try await gen.level(for: seed)
        }
    }

    func testWordOfTheDayIsDeterministicAndDateSensitive() {
        let a = DailyPuzzle.wordOfTheDay(forID: "daily-2026-07-02")
        let b = DailyPuzzle.wordOfTheDay(forID: "daily-2026-07-02")
        let c = DailyPuzzle.wordOfTheDay(forID: "daily-2026-07-03")
        XCTAssertNotNil(a)
        XCTAssertEqual(a?.word, b?.word)
        XCTAssertEqual(a?.theme, b?.theme)
        XCTAssertNotEqual(a?.word, c?.word)
    }

    func testWordOfTheDayThemeMatchesSeedTheme() {
        for day in 1...28 {
            let id = String(format: "daily-2026-07-%02d", day)
            let seed = DailyPuzzle.seed(forID: id)!
            let wotd = DailyPuzzle.wordOfTheDay(forID: id)!
            XCTAssertEqual(seed.theme, wotd.theme)
        }
    }

    func testWordOfTheDayWordIsEightToTenLetters() {
        for day in 1...28 {
            let id = String(format: "daily-2026-07-%02d", day)
            let word = DailyPuzzle.wordOfTheDay(forID: id)!.word
            XCTAssertTrue((8...10).contains(word.count), "\(word) is \(word.count) letters")
        }
    }

    func testWordOfTheDayRejectsGarbage() {
        XCTAssertNil(DailyPuzzle.wordOfTheDay(forID: "daily-not-a-date"))
        XCTAssertNil(DailyPuzzle.wordOfTheDay(forID: "zen-easy-0"))
    }
}
