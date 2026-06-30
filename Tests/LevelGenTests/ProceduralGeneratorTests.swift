import XCTest
import GameCore
@testable import LevelGen

final class ProceduralGeneratorTests: XCTestCase {
    let pools = ThemePools(
        scenes: [.zen: ["garden"], .doom: ["crypt"]],
        creatures: [.zen: ["koi"], .doom: ["shoggoth"]]
    )

    func makeGen() -> ProceduralGenerator {
        ProceduralGenerator(wordProvider: DeterministicWordProvider(), pools: pools)
    }

    func test_levelIsDeterministicForSameSeed() {
        let seed = LevelSeed(theme: .zen, band: .medium, index: 2)
        let a = makeGen().level(for: seed)
        let b = makeGen().level(for: seed)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.wheel.tiles.map(\.letter), b.wheel.tiles.map(\.letter))
        XCTAssertEqual(a.slots.map(\.answer), b.slots.map(\.answer))
    }

    func test_everySlotWordIsBuildableFromWheel_andGridNonEmpty() {
        let level = makeGen().level(for: LevelSeed(theme: .doom, band: .hard, index: 0))
        XCTAssertFalse(level.slots.isEmpty)
        let multiset = level.wheel.multiset
        for slot in level.slots {
            XCTAssertTrue(multiset.canBuild(slot.answer), "\(slot.answer) not buildable")
        }
    }

    func test_idEncodesSeed() {
        let level = makeGen().level(for: LevelSeed(theme: .doom, band: .hard, index: 5))
        XCTAssertEqual(level.id, "doom-hard-5")
    }
}
