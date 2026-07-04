import XCTest
import LevelGen
@testable import ZenWordOfDoom

final class ParchmentChromeTests: XCTestCase {
    func testAssetNameMapping() {
        XCTAssertEqual(ParchmentShape.assetName(theme: .zen, shape: .wide), "frame-zen-button")
        XCTAssertEqual(ParchmentShape.assetName(theme: .doom, shape: .wide), "frame-doom-button")
        XCTAssertEqual(ParchmentShape.assetName(theme: .zen, shape: .icon), "frame-zen-icon")
        XCTAssertEqual(ParchmentShape.assetName(theme: .doom, shape: .icon), "frame-doom-icon")
        XCTAssertEqual(ParchmentShape.assetName(theme: .zen, shape: .strip), "frame-zen-strip")
        XCTAssertEqual(ParchmentShape.assetName(theme: .doom, shape: .strip), "frame-doom-strip")
    }
}
