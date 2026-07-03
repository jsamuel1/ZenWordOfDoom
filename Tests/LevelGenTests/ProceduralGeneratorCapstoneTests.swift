import XCTest
import GameCore
@testable import LevelGen

/// Capstone / scene-coupling behaviour of the generator, using the real bundled
/// pools so scene coupling and signature creatures resolve.
final class ProceduralGeneratorCapstoneTests: XCTestCase {
    private func gen() -> ProceduralGenerator {
        ProceduralGenerator(wordProvider: DeterministicWordProvider(), pools: .zenDoom)
    }

    func testCapstoneProducesPangramHunt() async throws {
        // Order 9 is the capstone of pack 0.
        let seed = ProceduralLevelLibrary.standard.seed(atOrder: 9)
        let level = try await gen().level(for: seed)

        guard case .pangramHunt(let target) = level.format else {
            return XCTFail("expected pangramHunt, got \(level.format)")
        }
        XCTAssertGreaterThanOrEqual(target, 1)
        XCTAssertTrue(level.slots.isEmpty, "boss has no grid")
        // The wheel is a real N-letter word, so a pangram exists.
        let wheelWord = String(level.wheel.tiles.map(\.letter))
        XCTAssertEqual(wheelWord.count, level.wheel.size)
        XCTAssertTrue(level.wheel.multiset.canBuild(wheelWord))
    }

    func testCapstoneSignatureCreatureMatchesTheme() async throws {
        let seed = ProceduralLevelLibrary.standard.seed(atOrder: 9)
        let level = try await gen().level(for: seed)
        let pool = ThemePools.zenDoom.creatures[seed.theme] ?? []
        XCTAssertTrue(pool.contains(level.creatureID),
                      "signature \(level.creatureID) not in \(seed.theme) pool")
    }

    func testNonCapstoneStaysCrossword() async throws {
        let seed = ProceduralLevelLibrary.standard.seed(atOrder: 3)
        let level = try await gen().level(for: seed)
        XCTAssertEqual(level.format, .crossword)
        XCTAssertFalse(level.slots.isEmpty)
    }

    func testDeterministicAtCapstone() async throws {
        let seed = ProceduralLevelLibrary.standard.seed(atOrder: 19)
        let a = try await gen().level(for: seed)
        let b = try await gen().level(for: seed)
        XCTAssertEqual(a.wheel.tiles.map(\.letter), b.wheel.tiles.map(\.letter))
        XCTAssertEqual(a.creatureID, b.creatureID)
    }

    func testDailyLevelIsPangramHuntBuiltFromTheWord() {
        let seed = LevelSeed(theme: .zen, band: .medium, index: 1_234_567)
        let level = gen().dailyLevel(for: seed, word: "SERENITY")

        XCTAssertEqual(level.wheel.tiles.map(\.letter).map(String.init).joined(), "SERENITY")
        XCTAssertTrue(level.slots.isEmpty, "daily bonus level has no grid")
        guard case .pangramHunt(let target) = level.format else {
            return XCTFail("expected pangramHunt, got \(level.format)")
        }
        // SERENITY is 8 letters -> DifficultyBand.expert -> target 7.
        XCTAssertEqual(target, 7)
    }

    func testDailyLevelSceneIsTheWordsSlugAndCreatureIsFromThemePool() {
        let seed = LevelSeed(theme: .doom, band: .medium, index: 42)
        let level = gen().dailyLevel(for: seed, word: "NIGHTMARE")

        XCTAssertEqual(level.sceneID, WordOfTheDayImages.slug(forWord: "NIGHTMARE", theme: .doom))
        XCTAssertTrue((ThemePools.zenDoom.creatures[.doom] ?? []).contains(level.creatureID))
    }

    func testDailyLevelBandComesFromWordLengthNotSeedBand() {
        // Seed says .medium (implying a 6-letter wheel), but the actual word
        // is 10 letters -> the daily level's target must reflect the word's
        // real length, not the seed's nominal band.
        let seed = LevelSeed(theme: .zen, band: .medium, index: 7)
        let level = gen().dailyLevel(for: seed, word: "WELLSPRING")
        guard case .pangramHunt(let target) = level.format else {
            return XCTFail("expected pangramHunt")
        }
        XCTAssertEqual(target, PackCatalog.pangramTarget(for: .master))
    }

    func testDailyLevelIsDeterministic() {
        let seed = LevelSeed(theme: .zen, band: .hard, index: 99)
        let a = gen().dailyLevel(for: seed, word: "SANCTUARY")
        let b = gen().dailyLevel(for: seed, word: "SANCTUARY")
        XCTAssertEqual(a.creatureID, b.creatureID)
        XCTAssertEqual(a.sceneID, b.sceneID)
    }
}
