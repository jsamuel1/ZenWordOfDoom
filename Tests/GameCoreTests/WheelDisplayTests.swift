import XCTest
@testable import GameCore

final class WheelDisplayTests: XCTestCase {
    func testDisplayOrderIsPermutationOfTileIDs() {
        let wheel = Wheel(letters: "STONED")
        let order = wheel.displayOrder(seed: 42)
        XCTAssertEqual(order.count, wheel.tiles.count)
        XCTAssertEqual(Set(order), Set(wheel.tiles.map(\.id)),
                       "shuffle must preserve the exact tile-id set (letters unchanged)")
    }

    func testDisplayOrderDeterministic() {
        let w = Wheel(letters: "STONED")
        XCTAssertEqual(w.displayOrder(seed: 7), w.displayOrder(seed: 7))
    }

    func testSaltReRollsOrder() {
        let w = Wheel(letters: "PLANETS")
        let a = w.displayOrder(seed: 1, salt: 0)
        let b = w.displayOrder(seed: 1, salt: 1)
        let c = w.displayOrder(seed: 1, salt: 2)
        XCTAssertFalse(a == b && b == c, "different salts should change the order")
        // Each re-roll is still a valid permutation.
        for order in [a, b, c] {
            XCTAssertEqual(Set(order), Set(w.tiles.map(\.id)))
        }
    }
}
