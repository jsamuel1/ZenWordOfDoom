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

    func test_themeSwapsOnPrimeLevelNumbers() {
        // Level numbers are 1-indexed (order + 1). Zen is the baseline; each prime
        // level number permanently swaps the theme going forward. See worked
        // example in the commit/PR description for the derivation.
        let expected: [Theme] = [.zen, .doom, .zen, .zen, .doom, .doom, .zen, .zen, .zen, .zen, .doom, .doom]
        for (order, theme) in expected.enumerated() {
            XCTAssertEqual(lib.seed(atOrder: order).theme, theme, "level \(order + 1)")
        }
    }

    func test_lookupByIDRoundTrips() {
        let seed = lib.seed(atOrder: 13)
        XCTAssertEqual(lib.seed(forID: seed.id)?.id, seed.id)
        XCTAssertNil(lib.seed(forID: "nonsense-id-x"))
    }

    func testOrderIDRoundTrip() {
        let lib = ProceduralLevelLibrary()
        for order in [0, 1, 9, 10, 25, 100] {
            let id = lib.id(atOrder: order)
            XCTAssertEqual(lib.order(forID: id), order)
        }
    }
    func testNextIDAdvancesByOne() {
        let lib = ProceduralLevelLibrary()
        let id5 = lib.id(atOrder: 5)
        XCTAssertEqual(lib.nextID(after: id5), lib.id(atOrder: 6))
    }
    func testNextIDNilForUnknownID() {
        XCTAssertNil(ProceduralLevelLibrary().nextID(after: "not-a-real-id"))
    }
    func testIDsThroughIsContiguous() {
        let lib = ProceduralLevelLibrary()
        let ids = lib.ids(through: 12)
        XCTAssertEqual(ids.count, 13)
        XCTAssertEqual(ids.first, lib.id(atOrder: 0))
        XCTAssertEqual(ids.last, lib.id(atOrder: 12))
    }
    func testWheelSizeForIDMatchesBand() {
        let lib = ProceduralLevelLibrary()
        let id = lib.id(atOrder: 0)
        XCTAssertEqual(lib.wheelSize(forID: id), WheelPicker.wheelLength(for: .easy))
    }
    func testStandardIsUsable() {
        XCTAssertEqual(ProceduralLevelLibrary.standard.id(atOrder: 0),
                       ProceduralLevelLibrary().id(atOrder: 0))
    }
}
