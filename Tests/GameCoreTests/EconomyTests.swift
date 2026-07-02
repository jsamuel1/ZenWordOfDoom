import XCTest
@testable import GameCore

/// Pins the single serenity price list — every faucet and sink in the app
/// should read from `Economy`, not carry its own hardcoded numbers.
final class EconomyTests: XCTestCase {
    func testHintCost() {
        XCTAssertEqual(Economy.hintCost, 10)
    }

    func testBonusWordReward() {
        XCTAssertEqual(Economy.bonusWordReward, 1)
    }

    func testFirstClearNoHintPaysEight() {
        XCTAssertEqual(Economy.clearReward(firstClear: true, usedHint: false, voided: false), 8)
    }

    func testFirstClearWithHintPaysFive() {
        XCTAssertEqual(Economy.clearReward(firstClear: true, usedHint: true, voided: false), 5)
    }

    func testReplayClearPaysNothing() {
        XCTAssertEqual(Economy.clearReward(firstClear: false, usedHint: false, voided: false), 0)
        XCTAssertEqual(Economy.clearReward(firstClear: false, usedHint: true, voided: false), 0)
    }

    func testVoidedClearAlwaysPaysNothing() {
        XCTAssertEqual(Economy.clearReward(firstClear: true, usedHint: false, voided: true), 0)
        XCTAssertEqual(Economy.clearReward(firstClear: true, usedHint: true, voided: true), 0)
        XCTAssertEqual(Economy.clearReward(firstClear: false, usedHint: false, voided: true), 0)
    }
}
