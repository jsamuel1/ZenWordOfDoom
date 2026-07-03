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

    /// Every Word-of-the-Day slug must have its *own* prompt, not silently
    /// fall through to the generic per-theme placeholder (the two exact
    /// strings `VisualPrompts` falls back to for an unrecognized slug) —
    /// that fallback is what every one of these 24 slugs gets *before* this
    /// task adds real entries, so this genuinely fails first.
    func testEveryWordOfTheDaySlugHasItsOwnPromptNotTheGenericFallback() {
        let genericZen = "a serene minimalist nature scene, soft pastel light, calm illustration"
        let genericDoom = "an ancient ruined place at night, faint eerie glow, ominous stylized illustration"
        for theme in Theme.allCases {
            for slug in WordOfTheDayImages.slugs(for: theme) {
                let prompt = VisualPrompts.prompt(forSceneID: slug, theme: theme)
                XCTAssertFalse(prompt.isEmpty, "slug \(slug)")
                XCTAssertNotEqual(prompt, genericZen, "slug \(slug) fell through to the generic zen prompt")
                XCTAssertNotEqual(prompt, genericDoom, "slug \(slug) fell through to the generic doom prompt")
            }
        }
    }

    func testWordOfTheDaySlugPromptsAvoidNamedIP() {
        let banned = ["cthulhu", "doomguy", "buffy", "doom guy"]
        for theme in Theme.allCases {
            for slug in WordOfTheDayImages.slugs(for: theme) {
                let p = VisualPrompts.prompt(forSceneID: slug, theme: theme).lowercased()
                for token in banned { XCTAssertFalse(p.contains(token), "\(slug) leaks \(token)") }
            }
        }
    }
}
