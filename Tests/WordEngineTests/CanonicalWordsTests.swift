import XCTest
import GameCore
@testable import WordEngine

final class CanonicalWordsTests: XCTestCase {
    /// The canonical word list, copied verbatim from the contract, so the test
    /// fails if `SampleWords.canonical` ever drops a word.
    private static let canonicalList: [String] = [
        "STONE", "STONED", "NODE", "NODES", "NOTE", "NOTES", "TONE", "TONES",
        "DOT", "DOTS", "DOTE", "DOSE", "DONE", "NOSE", "ODE", "ODES", "TEN",
        "TENS", "NET", "NETS", "SET", "SON", "TON", "TONS", "EON", "EONS",
        "TOE", "TOES", "SNOT", "ONSET",
        "CALM", "CLAM", "LAMP", "LAMPS", "PALM", "PALMS", "MAPLE", "AMPLE",
        "PLEA", "PEAL", "PALE", "PALES", "LEAP", "LEAPS", "MEAL", "MEALS",
        "LAME", "LAMES", "SEAL", "MALE", "MALES",
        "GARDEN", "GRADE", "GRADES", "RANGE", "RANGED", "DANGER", "GANDER",
        "ANGER", "RAGED", "GRAND", "READ", "DEAR", "DARE", "DARES", "RAGE",
        "RAGES", "GEAR", "GEARS", "NEAR", "DEAN", "DEANS",
        "LOTUS", "LOUT", "LOUTS", "SOUL", "SLOT", "SLOTS", "LOST", "LOTS",
        "OUST", "TOIL", "SILO", "SOIL", "COIL", "COILS", "STOIC",
        "SHADOW", "SHADE", "SHADES", "HEADS", "AHEAD", "HASTE", "HEATS",
        "HATE", "HATES", "HEAT", "EARTH", "HEART", "HEARTS",
        "EMBER", "EMBERS", "MERGE", "TIMBER", "LIMBER",
        "RIVER", "DRIVE", "DRIVER", "DIVER", "RIDE", "RIDES", "DIRE", "DIVE",
        "FIRED", "FRIED",
    ]

    func testEveryCanonicalWordIsValid() {
        let dict = SampleWords.dictionary
        for word in Self.canonicalList {
            XCTAssertTrue(dict.isValidWord(word),
                          "canonical word \(word) must be in the dictionary")
            // case-insensitivity should hold for canonical words too
            XCTAssertTrue(dict.isValidWord(word.lowercased()),
                          "canonical word \(word) must validate case-insensitively")
        }
    }

    func testCanonicalListExposesEveryCanonicalWord() {
        let listed = Set(SampleWords.canonical.map { $0.uppercased() })
        for word in Self.canonicalList {
            XCTAssertTrue(listed.contains(word),
                          "SampleWords.canonical is missing \(word)")
        }
    }

    func testListIsDeduplicated() {
        let list = SampleWords.list
        XCTAssertEqual(list.count, Set(list).count, "SampleWords.list must contain no duplicates")
    }

    func testListContainsEveryCanonicalWord() {
        let listed = Set(SampleWords.list)
        for word in Self.canonicalList {
            XCTAssertTrue(listed.contains(word),
                          "SampleWords.list is missing canonical word \(word)")
        }
    }

    func testBuildableFromFiltersByWheelLetters() {
        let dict = SampleWords.dictionary

        // CALM wheel: only words buildable from C,A,L,M,P,E,S should appear.
        let calm = dict.words(buildableFrom: LetterMultiset("MAPLES"), minLength: 3)
        XCTAssertTrue(calm.contains("MAPLE"))
        XCTAssertTrue(calm.contains("AMPLE"))
        XCTAssertTrue(calm.contains("PALES"))
        // STONE has no letters from MAPLES, must be filtered out.
        XCTAssertFalse(calm.contains("STONE"), "STONE is not buildable from MAPLES")
        XCTAssertTrue(calm.allSatisfy { $0.count >= 3 })

        // GARDEN wheel.
        let garden = dict.words(buildableFrom: LetterMultiset("GARDEN"), minLength: 3)
        XCTAssertTrue(garden.contains("GARDEN"))
        XCTAssertTrue(garden.contains("DANGER"))
        XCTAssertTrue(garden.contains("RANGE"))
        XCTAssertFalse(garden.contains("LOTUS"), "LOTUS is not buildable from GARDEN")
    }

    func testMinLengthIsRespected() {
        let dict = SampleWords.dictionary
        let words = dict.words(buildableFrom: LetterMultiset("STONED"), minLength: 4)
        XCTAssertTrue(words.allSatisfy { $0.count >= 4 })
        XCTAssertFalse(words.contains("DOT"), "3-letter DOT excluded at minLength 4")
        XCTAssertTrue(words.contains("STONE"))
    }
}
