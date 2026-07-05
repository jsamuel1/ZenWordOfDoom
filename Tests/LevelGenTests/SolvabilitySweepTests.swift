import XCTest
import GameCore
@testable import LevelGen

final class SolvabilitySweepTests: XCTestCase {
    func test_first50LevelsAreValid() async throws {
        let pools = ThemePools(
            scenes: [.zen: ["garden", "pond"], .doom: ["crypt", "abyss"]],
            creatures: [.zen: ["koi", "crane"], .doom: ["shoggoth", "vampire"]]
        )
        let lib = ProceduralLevelLibrary(packSize: 10)
        let gen = ProceduralGenerator(wordProvider: DeterministicWordProvider(), pools: pools)
        for order in 0..<50 {
            let level = try await gen.level(for: lib.seed(atOrder: order))
            let multiset = level.wheel.multiset

            // Pack capstones are grid-less Pangram-Hunt bosses; assert the boss
            // invariant (a pangram exists) instead of grid validity.
            if case .pangramHunt = level.format {
                XCTAssertTrue(level.slots.isEmpty, "order \(order): boss should have no grid")
                let wheelWord = String(level.wheel.tiles.map(\.letter))
                XCTAssertTrue(multiset.canBuild(wheelWord),
                              "order \(order): boss wheel admits no pangram")
                continue
            }

            XCTAssertGreaterThanOrEqual(level.slots.count, 1, "order \(order): empty grid")
            for slot in level.slots {
                XCTAssertTrue(multiset.canBuild(slot.answer), "order \(order): \(slot.answer) unbuildable")
            }
            // No two slots conflict on a shared cell.
            var m: [GridCoord: Character] = [:]
            for slot in level.slots {
                let chars = Array(slot.answer)
                for (i, cell) in slot.cells.enumerated() {
                    if let e = m[cell] {
                        XCTAssertEqual(e, chars[i], "order \(order): conflict at \(cell)")
                    } else {
                        m[cell] = chars[i]
                    }
                }
            }
        }
    }

    /// The same sweep against the REAL shipped content — `ThemePools.zenDoom`
    /// scenes/creatures and the bundled anchor pools — so content-quality
    /// regressions (word-poor wheels, boss anchors missing from the corpus,
    /// letters repeating on consecutive levels) are caught at test time
    /// rather than discovered by long-tail players. 160 orders covers all
    /// three richness tiers (easy/medium/hard eras end at order 150) plus
    /// the start of the infinite hard tail. The fake-pool test above stays
    /// as the fast structural check.
    func test_realContentFirst160LevelsAreRichAndNonRepeating() async throws {
        let lib = ProceduralLevelLibrary(packSize: 10)
        let gen = ProceduralGenerator(wordProvider: DeterministicWordProvider(), pools: .zenDoom)
        var previousSignature = ""
        for order in 0..<160 {
            let level = try await gen.level(for: lib.seed(atOrder: order))
            let wheelWord = String(level.wheel.tiles.map(\.letter))
            let signature = String(wheelWord.sorted())

            // Anti-repeat: never the same letters two levels in a row (the
            // old scene-lexicon wheels repeated at master band).
            XCTAssertNotEqual(signature, previousSignature,
                              "order \(order): same wheel letters as order \(order - 1)")
            previousSignature = signature

            // Every wheel anchor must be a real, common corpus word — it is
            // the guaranteed pangram on boss levels.
            XCTAssertTrue(GeneralWordList.shared.contains(wheelWord),
                          "order \(order): anchor \(wheelWord) missing from corpus")

            if case .pangramHunt(let target) = level.format {
                let buildable = GeneralWordList.shared.buildableWords(from: level.wheel.multiset)
                XCTAssertGreaterThanOrEqual(buildable.count, target,
                                            "order \(order): boss target \(target) exceeds \(buildable.count) buildable words")
                continue
            }

            // Known-good anchors guarantee an interesting pool, so the grid
            // should never need to fall back below three slots.
            XCTAssertGreaterThanOrEqual(level.slots.count, 3,
                                        "order \(order): only \(level.slots.count) slots on \(wheelWord)")
        }
    }
}
