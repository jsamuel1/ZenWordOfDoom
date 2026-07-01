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
}
