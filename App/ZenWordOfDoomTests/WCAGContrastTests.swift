import XCTest
import SwiftUI
@testable import ZenWordOfDoom

final class WCAGContrastTests: XCTestCase {
    private func ratio(_ a: Color, _ b: Color) -> Double {
        AccessibilityPalette.contrastRatio(a, b)
    }

    func testWheelTilePairsMeetAA() {
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.wheelTileText,
                                          AccessibilityPalette.wheelTileFill), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.wheelTileSelectedText,
                                          AccessibilityPalette.wheelTileSelectedFill), 4.5)
    }

    func testGridPairsMeetAA() {
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.gridSolvedText,
                                          AccessibilityPalette.gridSolvedFill), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.gridFilledText,
                                          AccessibilityPalette.gridFilledFill), 4.5)
        // Cell boundary vs its own fill: UI component, 3:1 floor.
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.gridCellStroke,
                                          AccessibilityPalette.gridUnfilledFill), 3.0)
    }

    func testParchmentPairsMeetAA() {
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.parchmentInkZen,
                                          AccessibilityPalette.parchmentScrimZen), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.parchmentInkDoom,
                                          AccessibilityPalette.parchmentScrimDoom), 4.5)
    }

    func testKnownRatioSanity() {
        XCTAssertEqual(ratio(.black, .white), 21.0, accuracy: 0.1)
        XCTAssertEqual(ratio(.white, .white), 1.0, accuracy: 0.05)
    }
}
