import XCTest
import SwiftUI
import LevelGen
@testable import ZenWordOfDoom

final class BrandFontThemedTests: XCTestCase {
    func testDoomThemeUsesGrenzeGotisch() {
        XCTAssertEqual(
            BrandFont.themed(.doom, size: 22, relativeTo: .headline),
            BrandFont.doom(size: 22, relativeTo: .headline)
        )
    }

    func testZenThemeUsesBuda() {
        XCTAssertEqual(
            BrandFont.themed(.zen, size: 22, relativeTo: .headline),
            BrandFont.zen(size: 22, relativeTo: .headline)
        )
    }
}
