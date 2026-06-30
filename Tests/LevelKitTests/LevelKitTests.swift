import XCTest
@testable import LevelKit

final class LevelKitTests: XCTestCase {
    func testCutSceneDataRoundTrips() throws {
        let original = CutSceneData(id: "zen-easy-0", scene: "still-pond",
                                    creature: "koi-spirit",
                                    poem: ["a", "b", "c"], popoutDelay: 2.0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CutSceneData.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.scene, original.scene)
        XCTAssertEqual(decoded.creature, original.creature)
        XCTAssertEqual(decoded.poem, original.poem)
        XCTAssertEqual(decoded.popoutDelay, original.popoutDelay)
    }
}
