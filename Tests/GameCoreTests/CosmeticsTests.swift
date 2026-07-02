import XCTest
@testable import GameCore

final class CosmeticsTests: XCTestCase {
    func testCatalogIDsAreUnique() {
        let ids = CosmeticsCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testCostsSitInsideTheSmallNumberEconomy() {
        for c in CosmeticsCatalog.all {
            XCTAssertTrue((25...75).contains(c.cost), "\(c.id) cost \(c.cost) out of spec range")
        }
    }

    func testBothKindsShip() {
        XCTAssertFalse(CosmeticsCatalog.items(of: .palette).isEmpty)
        XCTAssertFalse(CosmeticsCatalog.items(of: .poemSet).isEmpty)
    }

    func testLookupByID() {
        XCTAssertEqual(CosmeticsCatalog.cosmetic(id: "palette-ember")?.kind, .palette)
        XCTAssertNil(CosmeticsCatalog.cosmetic(id: "no-such-thing"))
    }
}
