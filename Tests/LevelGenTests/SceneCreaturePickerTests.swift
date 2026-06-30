import XCTest
@testable import LevelGen

final class SceneCreaturePickerTests: XCTestCase {
    let pools = ThemePools(
        scenes: [.zen: ["garden", "pond"], .doom: ["crypt", "abyss"]],
        creatures: [.zen: ["koi"], .doom: ["shoggoth", "vampire"]]
    )

    func test_picksFromTheCorrectThemePool() {
        let pick = SceneCreaturePicker(pools: pools).pick(theme: .doom, index: 0)
        XCTAssertTrue(pools.scenes[.doom]!.contains(pick.sceneID))
        XCTAssertTrue(pools.creatures[.doom]!.contains(pick.creatureID))
    }

    func test_isDeterministic() {
        let p = SceneCreaturePicker(pools: pools)
        XCTAssertEqual(p.pick(theme: .zen, index: 4).sceneID, p.pick(theme: .zen, index: 4).sceneID)
        XCTAssertEqual(p.pick(theme: .zen, index: 4).creatureID, p.pick(theme: .zen, index: 4).creatureID)
    }
}
