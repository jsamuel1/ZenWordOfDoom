import XCTest
import GameCore
@testable import LevelGen

final class LevelGenErrorTests: XCTestCase {
    func testEveryRealBandAndThemeHasAnchorWords() {
        // Every real theme lexicon must supply an anchor word at every band's
        // wheel length, so wheel picking never throws for shipped content.
        for theme in [Theme.zen, .doom] {
            for band in [DifficultyBand.easy, .medium, .hard, .expert, .master] {
                XCTAssertNoThrow(try WheelPicker.wheel(theme: theme, band: band, index: 1))
            }
        }
    }

    func testLevelGenErrorEquatableRoundTrip() {
        // The error type itself: cases carry their diagnostics and compare by
        // value, so callers can pattern-match on exactly what failed. (The
        // throwing paths can't be forced with the real bundled lexicons —
        // every band/theme has anchors by design — so this pins the error
        // surface itself rather than pretending to probe an impossible throw.)
        let anchorless = LevelGenError.noAnchorWord(theme: .zen, length: 9)
        XCTAssertEqual(anchorless, .noAnchorWord(theme: .zen, length: 9))
        XCTAssertNotEqual(anchorless, .noAnchorWord(theme: .doom, length: 9))
        XCTAssertNotEqual(anchorless, .noAnchorWord(theme: .zen, length: 5))

        let empty = LevelGenError.emptyGrid(seedID: "x", poolSize: 0)
        XCTAssertEqual(empty, .emptyGrid(seedID: "x", poolSize: 0))
        XCTAssertNotEqual(empty, .emptyGrid(seedID: "y", poolSize: 0))
        XCTAssertNotEqual(anchorless, empty)
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
