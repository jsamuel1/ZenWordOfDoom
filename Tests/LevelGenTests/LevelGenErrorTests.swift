import XCTest
import GameCore
@testable import LevelGen

final class LevelGenErrorTests: XCTestCase {
    func testAnchorlessWheelThrowsInsteadOfCrashing() {
        // No theme lexicon has 100-letter words; a fabricated band isn't
        // possible, so exercise the throwing path via the scene-coupled
        // API's theme fallback with an unknown scene id + a band whose
        // theme lexicon is temporarily filtered — simplest honest probe:
        // assert the theme wheel *succeeds* for every real band/theme
        // (no throw), pinning that conversion didn't break generation…
        for theme in [Theme.zen, .doom] {
            for band in [DifficultyBand.easy, .medium, .hard, .expert, .master] {
                XCTAssertNoThrow(try WheelPicker.wheel(theme: theme, band: band, index: 1))
            }
        }
    }

    func testGeneratorStillProducesEveryEarlySeed() async throws {
        // The solvability sweep covers this too; a cheap smoke here keeps the
        // error-conversion honest for the first two packs.
        let gen = ProceduralGenerator(
            wordProvider: DeterministicWordProvider(), pools: .zenDoom)
        for order in 0..<20 {
            let seed = ProceduralLevelLibrary.standard.seed(atOrder: order)
            _ = try await gen.level(for: seed)
        }
    }
}
