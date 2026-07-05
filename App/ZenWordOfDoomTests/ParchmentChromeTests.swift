import XCTest
import UIKit
import LevelGen
@testable import ZenWordOfDoom

/// v3 chrome is entirely code-drawn (mat + thin two-tone accent outline) —
/// no bundled textures to verify anymore. These tests pin the shape metrics
/// and that the theme accents stay distinct.
final class ParchmentChromeTests: XCTestCase {
    func testShapeCornerRadii() {
        XCTAssertEqual(ParchmentShape.wide.cornerRadius, 12)
        XCTAssertEqual(ParchmentShape.icon.cornerRadius, 14)
        XCTAssertEqual(ParchmentShape.strip.cornerRadius, 10)
    }

    func testThemeAccentsAreDistinctTwoTonePairs() {
        XCTAssertNotEqual(AccessibilityPalette.parchmentAccent(for: .zen),
                          AccessibilityPalette.parchmentAccent(for: .doom),
                          "zen and doom must have different accent outlines")
        for theme in [Theme.zen, Theme.doom] {
            XCTAssertNotEqual(AccessibilityPalette.parchmentAccent(for: theme),
                              AccessibilityPalette.parchmentAccentSoft(for: theme),
                              "\(theme): outer and inlay tones must differ (two-tone)")
        }
    }
}
