import XCTest
import GameCore
@testable import LevelGen

final class VisualPromptsTests: XCTestCase {
    func testEverySlugHasNonEmptyPrompt() {
        let pools = ThemePools.zenDoom
        for theme in Theme.allCases {
            for id in pools.scenes[theme] ?? [] {
                XCTAssertFalse(VisualPrompts.prompt(forSceneID: id, theme: theme).isEmpty, "scene \(id)")
            }
            for id in pools.creatures[theme] ?? [] {
                XCTAssertFalse(VisualPrompts.prompt(forCreatureID: id, theme: theme).isEmpty, "creature \(id)")
            }
        }
    }
    func testPromptsAvoidNamedIP() {
        let banned = ["cthulhu", "doomguy", "buffy", "doom guy"]
        let pools = ThemePools.zenDoom
        for theme in Theme.allCases {
            for id in (pools.scenes[theme] ?? []) + (pools.creatures[theme] ?? []) {
                let p = (VisualPrompts.prompt(forSceneID: id, theme: theme)
                         + " " + VisualPrompts.prompt(forCreatureID: id, theme: theme)).lowercased()
                for token in banned { XCTAssertFalse(p.contains(token), "\(id) leaks \(token)") }
            }
        }
    }
    func testUnknownSlugFallsBackByTheme() {
        XCTAssertFalse(VisualPrompts.prompt(forSceneID: "totally-unknown", theme: .doom).isEmpty)
    }
    func testPromptVersionIsPositive() { XCTAssertGreaterThan(VisualPrompts.promptVersion, 0) }
}
