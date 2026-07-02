import XCTest
import GameCore
@testable import LevelGen

final class WheelPickerTests: XCTestCase {
    func test_wheelLengthMatchesBand() {
        let cases: [(DifficultyBand, Int)] = [(.easy,5),(.medium,6),(.hard,7),(.expert,8),(.master,9)]
        for (band, n) in cases {
            XCTAssertEqual(WheelPicker.wheel(theme: .zen, band: band, index: 0).size, n,
                           "band \(band) wheel size")
        }
    }

    func test_isDeterministic() {
        let a = WheelPicker.wheel(theme: .doom, band: .hard, index: 3)
        let b = WheelPicker.wheel(theme: .doom, band: .hard, index: 3)
        XCTAssertEqual(a.tiles.map(\.letter), b.tiles.map(\.letter))
    }

    func test_baseWordIsAThemeAnchorOfCorrectLength() {
        let wheel = WheelPicker.wheel(theme: .zen, band: .hard, index: 1)
        let letters = String(wheel.tiles.map(\.letter))
        XCTAssertEqual(letters.count, 7)
        XCTAssertTrue(ThemeLexicon.shared.contains(letters, theme: .zen))
    }

    /// v0.3 consolidated WheelPicker's inline FNV-1a with GameCore.FNV1a. The seeds
    /// drive every generated level, so they must be byte-identical forever.
    func testSeedUnchangedByFNV1aConsolidation() {
        func expectedSeed(theme: Theme, band: DifficultyBand, index: Int) -> UInt64 {
            FNV1a.hash(theme.rawValue + band.rawValue + "\(index)")
        }
        for (theme, band, index) in [(Theme.zen, DifficultyBand.easy, 0),
                                     (.doom, .master, 41), (.zen, .expert, 999)] {
            XCTAssertEqual(WheelPicker.seed(theme: theme, band: band, index: index),
                           expectedSeed(theme: theme, band: band, index: index))
        }
    }
}
