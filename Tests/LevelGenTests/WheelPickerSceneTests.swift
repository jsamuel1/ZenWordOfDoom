import XCTest
@testable import LevelGen
import GameCore

final class WheelPickerSceneTests: XCTestCase {
    func testSceneAnchorUsesSceneWordWhenAvailable() {
        // still-pond has length-6 words; medium band => N=6.
        let wheel = WheelPicker.wheel(sceneID: "still-pond", theme: .zen, band: .medium, index: 0)
        XCTAssertEqual(wheel.size, 6)
        let letters = String(wheel.tiles.map(\.letter)).sorted()
        let sceneWords6 = SceneLexicon.shared.words(for: "still-pond").filter { $0.count == 6 }
        XCTAssertTrue(sceneWords6.contains { $0.sorted() == letters },
                      "wheel letters should match a length-6 scene word")
    }

    func testFallsBackToThemeAnchorForUnknownScene() {
        // No lexicon words => must still yield a valid N-letter wheel.
        let wheel = WheelPicker.wheel(sceneID: "no-such-scene", theme: .zen, band: .medium, index: 3)
        XCTAssertEqual(wheel.size, 6)
    }

    func testDeterministic() {
        let a = WheelPicker.wheel(sceneID: "still-pond", theme: .zen, band: .hard, index: 7)
        let b = WheelPicker.wheel(sceneID: "still-pond", theme: .zen, band: .hard, index: 7)
        XCTAssertEqual(String(a.tiles.map(\.letter)), String(b.tiles.map(\.letter)))
    }
}
