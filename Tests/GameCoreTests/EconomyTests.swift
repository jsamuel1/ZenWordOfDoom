import XCTest
@testable import GameCore

/// Pins the single serenity price list — every faucet and sink in the app
/// should read from `Economy`, not carry its own hardcoded numbers. The
/// design target is ~0.8 hints' worth (~8 serenity) earned per level,
/// averaged over a pack with its boss payday.
final class EconomyTests: XCTestCase {
    func testHintCost() {
        XCTAssertEqual(Economy.hintCost, 10)
    }

    func testBonusWordReward() {
        XCTAssertEqual(Economy.bonusWordReward, 1)
    }

    func testBonusRewardsAreCappedPerLevel() {
        XCTAssertEqual(Economy.maxBonusRewardsPerLevel, 2)
    }

    func testStartingSerenity() {
        XCTAssertEqual(Economy.startingSerenity, 50)
    }

    func testBossClearReward() {
        XCTAssertEqual(Economy.bossClearReward, 50)
    }

    func testFirstClearNoHintPaysTwo() {
        XCTAssertEqual(Economy.clearReward(firstClear: true, usedHint: false, voided: false), 2)
    }

    func testFirstClearWithHintPaysOne() {
        XCTAssertEqual(Economy.clearReward(firstClear: true, usedHint: true, voided: false), 1)
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

    /// The pack-level design target: 9 clean normal clears with capped bonus
    /// words plus the boss beat lands within ~0.75-0.9 hints per level.
    func testPackYieldIsNearDesignTarget() {
        let normal = Economy.clearReward(firstClear: true, usedHint: false, voided: false)
            + Economy.maxBonusRewardsPerLevel * Economy.bonusWordReward
        let boss = Economy.clearReward(firstClear: true, usedHint: false, voided: false)
            + Economy.bossClearReward
            + Economy.maxBonusRewardsPerLevel * Economy.bonusWordReward
        let packYield = 9 * normal + boss
        let hintsPerLevel = Double(packYield) / Double(10 * Economy.hintCost)
        XCTAssertGreaterThanOrEqual(hintsPerLevel, 0.75, "economy drifted too stingy")
        XCTAssertLessThanOrEqual(hintsPerLevel, 0.9, "economy drifted too generous")
    }
}
