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

    func test_levelIsDeterministicForSameSeed() async throws {
        let seed = LevelSeed(theme: .zen, band: .medium, index: 2)
        let a = try await makeGen().level(for: seed)
        let b = try await makeGen().level(for: seed)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.wheel.tiles.map(\.letter), b.wheel.tiles.map(\.letter))
        XCTAssertEqual(a.slots.map(\.answer), b.slots.map(\.answer))
    }

    func test_everySlotWordIsBuildableFromWheel_andGridNonEmpty() async throws {
        let level = try await makeGen().level(for: LevelSeed(theme: .doom, band: .hard, index: 0))
        XCTAssertFalse(level.slots.isEmpty)
        let multiset = level.wheel.multiset
        for slot in level.slots {
            XCTAssertTrue(multiset.canBuild(slot.answer), "\(slot.answer) not buildable")
        }
    }

    func test_idEncodesSeed() async throws {
        let level = try await makeGen().level(for: LevelSeed(theme: .doom, band: .hard, index: 5))
        XCTAssertEqual(level.id, "doom-hard-5")
    }

    func test_gridAnswersAreOverwhelminglyInteresting() async throws {
        // Required answers should be on-theme or common words, not obscure corpus
        // entries — obscure words only slip in on rare word-poor wheels via the
        // fallback layout.
        let lexicon = ThemeLexicon.shared
        let common = CommonWords.shared
        let lib = ProceduralLevelLibrary(packSize: 10)
        let gen = makeGen()
        var total = 0
        var interesting = 0
        for order in 0..<30 {
            let seed = lib.seed(atOrder: order)
            let level = try await gen.level(for: seed)
            for slot in level.slots {
                total += 1
                if lexicon.contains(slot.answer, theme: seed.theme) || common.contains(slot.answer) {
                    interesting += 1
                }
            }
        }
        XCTAssertGreaterThan(Double(interesting) / Double(total), 0.85,
            "only \(interesting)/\(total) grid answers were themed or common")
    }
}
