import XCTest
import GameCore
@testable import LevelGen

final class ThemePoolsTests: XCTestCase {
    func testDefaultPoolsNonEmptyPerTheme() {
        let pools = ThemePools.zenDoom
        for theme in Theme.allCases {
            XCTAssertGreaterThanOrEqual(pools.scenes[theme]?.count ?? 0, 4)
            XCTAssertGreaterThanOrEqual(pools.creatures[theme]?.count ?? 0, 4)
        }
    }
    func testPickerOverDefaultPoolsIsStableAndInPool() {
        let picker = SceneCreaturePicker(pools: .zenDoom)
        let a = picker.pick(theme: .doom, index: 3)
        let b = picker.pick(theme: .doom, index: 3)
        XCTAssertEqual(a.sceneID, b.sceneID)
        XCTAssertEqual(a.creatureID, b.creatureID)
        XCTAssertTrue(ThemePools.zenDoom.scenes[.doom]!.contains(a.sceneID))
        XCTAssertTrue(ThemePools.zenDoom.creatures[.doom]!.contains(a.creatureID))
    }
}
