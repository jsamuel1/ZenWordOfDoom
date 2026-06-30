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
}
