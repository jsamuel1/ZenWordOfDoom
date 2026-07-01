import XCTest
@testable import LevelGen
import GameCore

final class PackCatalogTests: XCTestCase {
    private let c = PackCatalog.standard

    func testCapstoneDetection() {
        XCTAssertFalse(c.isCapstone(order: 0, packSize: 10))
        XCTAssertFalse(c.isCapstone(order: 8, packSize: 10))
        XCTAssertTrue(c.isCapstone(order: 9, packSize: 10))
        XCTAssertTrue(c.isCapstone(order: 19, packSize: 10))
    }

    func testPangramTargetByBand() {
        XCTAssertEqual(PackCatalog.pangramTarget(for: .easy), 4)
        XCTAssertEqual(PackCatalog.pangramTarget(for: .master), 8)
        XCTAssertGreaterThan(PackCatalog.pangramTarget(for: .hard),
                             PackCatalog.pangramTarget(for: .easy))
    }

    func testPackHasName() {
        XCTAssertFalse(c.pack(forOrder: 0, packSize: 10).name.isEmpty)
        XCTAssertEqual(c.pack(forOrder: 5, packSize: 10).index, 0)
        XCTAssertEqual(c.pack(forOrder: 15, packSize: 10).index, 1)
    }

    func testSignatureCreatureMatchesThemePool() {
        let doomSig = c.signatureCreatureID(forOrder: 9, packSize: 10, theme: .doom, pools: .zenDoom)
        XCTAssertTrue((ThemePools.zenDoom.creatures[.doom] ?? []).contains(doomSig))
        let zenSig = c.signatureCreatureID(forOrder: 19, packSize: 10, theme: .zen, pools: .zenDoom)
        XCTAssertTrue((ThemePools.zenDoom.creatures[.zen] ?? []).contains(zenSig))
    }
}
