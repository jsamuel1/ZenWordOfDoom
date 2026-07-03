import XCTest
import GameCore
import LevelGen
@testable import ZenWordOfDoom

@MainActor
final class LevelServiceTests: XCTestCase {
    func testDailyLevelIsWordOfTheDayPangramHunt() async throws {
        let service = LevelService()
        let id = "daily-2026-08-15"
        let expected = DailyPuzzle.wordOfTheDay(forID: id)!

        guard let level = await service.level(id: id) else {
            XCTFail("Expected to get a level for daily id \(id)")
            return
        }

        XCTAssertEqual(level.id, id)
        XCTAssertEqual(level.wheel.tiles.map(\.letter).map(String.init).joined(), expected.word)
        guard case .pangramHunt = level.format else {
            return XCTFail("expected pangramHunt, got \(level.format)")
        }
        XCTAssertTrue(level.slots.isEmpty)
    }

    func testDailyLevelIsMemoized() async throws {
        let service = LevelService()
        let id = "daily-2026-08-16"
        guard let first = await service.level(id: id) else {
            XCTFail("Expected to get a level for daily id \(id)")
            return
        }
        guard let second = await service.level(id: id) else {
            XCTFail("Expected to get a level for daily id \(id)")
            return
        }
        XCTAssertEqual(first.sceneID, second.sceneID)
        XCTAssertEqual(first.creatureID, second.creatureID)
    }

    /// Regression guard for the "bonus, not gating" requirement (design spec
    /// §2, §5.7): the daily slot's id space is entirely disjoint from the
    /// campaign's, so nothing about resolving/generating a daily level can
    /// ever affect `nextID(after:)`/`order(forID:)` for a campaign id.
    func testDailyIDsNeverAppearInCampaignOrdering() {
        let service = LevelService()
        let campaignIDs = service.ids(through: 30)
        XCTAssertTrue(campaignIDs.allSatisfy { !DailyPuzzle.isDailyID($0) })
        XCTAssertNil(service.order(forID: "daily-2026-08-15"))
    }
}
