import XCTest
@testable import GameCore

final class StoreTests: XCTestCase {
    // MARK: AdPolicy

    func testPackOneIsAdFree() {
        // Orders 0..9 (levels 1–10) never carry an ad, including the capstone breath.
        for order in 0..<AdPolicy.adFreeLevelCount {
            XCTAssertFalse(AdPolicy.shouldShowAd(afterLevelOrder: order, isPremium: false),
                           "order \(order) should be in the grace period")
        }
    }

    func testAdsStartAfterGracePeriodForFreePlayers() {
        XCTAssertTrue(AdPolicy.shouldShowAd(afterLevelOrder: 10, isPremium: false))
        XCTAssertTrue(AdPolicy.shouldShowAd(afterLevelOrder: 250, isPremium: false))
    }

    func testPremiumNeverSeesAds() {
        for order in [0, 9, 10, 999] {
            XCTAssertFalse(AdPolicy.shouldShowAd(afterLevelOrder: order, isPremium: true))
        }
    }

    // MARK: StoreItem

    func testSerenityAmountsMatchPricingSpec() {
        XCTAssertEqual(StoreItem.serenitySmall.serenityAmount, 45)
        XCTAssertEqual(StoreItem.serenityMedium.serenityAmount, 100)
        XCTAssertEqual(StoreItem.serenityLarge.serenityAmount, 220)
        XCTAssertNil(StoreItem.premiumRemoveAds.serenityAmount)
        XCTAssertFalse(StoreItem.premiumRemoveAds.isConsumable)
        XCTAssertTrue(StoreItem.serenitySmall.isConsumable)
    }

    /// Value per dollar must improve with pack size ($0.99/$1.99/$3.99) so no
    /// pack is ever strictly worse than buying multiples of a smaller one.
    func testNoPackIsDominated() {
        let small = Double(StoreItem.serenitySmall.serenityAmount!) / 0.99
        let medium = Double(StoreItem.serenityMedium.serenityAmount!) / 1.99
        let large = Double(StoreItem.serenityLarge.serenityAmount!) / 3.99
        XCTAssertGreaterThan(medium, small)
        XCTAssertGreaterThan(large, medium)
    }

    // MARK: SaveState backward compatibility

    func testOldSaveWithoutMonetizationKeysStillDecodes() throws {
        // The exact shape written by v0.1/v0.2 builds — no monetization keys.
        let old = """
        {"serenity": 42,
         "stats": {"levelsCleared": 7, "totalWordsFound": 30, "totalBonusWords": 5,
                   "longestWord": "STONED", "pangrams": 2, "creaturesRevealed": 1,
                   "currentStreak": 3, "bestStreak": 4},
         "progress": {"zen-easy-0": {"levelID": "zen-easy-0", "cleared": true,
                       "bestScore": 120, "bonusWordsFound": 2, "noHint": true}},
         "bestiary": {"gloom-eye": {"creatureID": "gloom-eye",
                       "firstRevealedLevelID": "doom-easy-2"}}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SaveState.self, from: old)
        XCTAssertEqual(decoded.serenity, 42, "existing progress must survive the upgrade")
        XCTAssertEqual(decoded.stats.levelsCleared, 7)
        XCTAssertEqual(decoded.progress.count, 1)
        XCTAssertEqual(decoded.bestiary.count, 1)
        // New fields default cleanly.
        XCTAssertFalse(decoded.premiumUnlocked)
        XCTAssertTrue(decoded.ownedCosmetics.isEmpty)
        XCTAssertNil(decoded.equippedPalette)
        XCTAssertTrue(decoded.processedTransactionIDs.isEmpty)
    }

    func testNewFieldsRoundTrip() throws {
        var s = SaveState()
        s.premiumUnlocked = true
        s.ownedCosmetics = ["palette-ember", "poems-abyss"]
        s.equippedPalette = "palette-ember"
        s.markTransactionProcessed(12345)
        let decoded = try JSONDecoder().decode(SaveState.self,
                                               from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded, s)
    }

    // MARK: Transaction dedupe

    func testMarkTransactionProcessedDedupes() {
        var s = SaveState()
        XCTAssertTrue(s.markTransactionProcessed(7))
        XCTAssertFalse(s.markTransactionProcessed(7), "replay must not credit twice")
        XCTAssertTrue(s.markTransactionProcessed(8))
    }

    func testProcessedTransactionListIsBounded() {
        var s = SaveState()
        for id in 0..<80 { s.markTransactionProcessed(UInt64(id)) }
        XCTAssertEqual(s.processedTransactionIDs.count, 50)
        XCTAssertEqual(s.processedTransactionIDs.first, 30, "oldest ids drop first")
        XCTAssertEqual(s.processedTransactionIDs.last, 79)
    }
}
