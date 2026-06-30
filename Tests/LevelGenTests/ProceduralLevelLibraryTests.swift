import XCTest
import GameCore
@testable import LevelGen

final class ProceduralLevelLibraryTests: XCTestCase {
    let lib = ProceduralLevelLibrary(packSize: 10)

    func test_orderedSeedsAreStableAndDistinct() {
        let ids = (0..<25).map { lib.seed(atOrder: $0).id }
        XCTAssertEqual(ids.count, Set(ids).count, "ids must be unique")
        XCTAssertEqual(lib.seed(atOrder: 0).id, ProceduralLevelLibrary(packSize: 10).seed(atOrder: 0).id)
    }

    func test_themeAlternatesPerPack() {
        XCTAssertEqual(lib.seed(atOrder: 0).theme, .zen)   // pack 0
        XCTAssertEqual(lib.seed(atOrder: 9).theme, .zen)
        XCTAssertEqual(lib.seed(atOrder: 10).theme, .doom) // pack 1
        XCTAssertEqual(lib.seed(atOrder: 20).theme, .zen)  // pack 2
    }

    func test_lookupByIDRoundTrips() {
        let seed = lib.seed(atOrder: 13)
        XCTAssertEqual(lib.seed(forID: seed.id)?.id, seed.id)
        XCTAssertNil(lib.seed(forID: "nonsense-id-x"))
    }
}
