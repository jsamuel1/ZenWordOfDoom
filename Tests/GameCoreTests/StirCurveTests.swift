import XCTest
@testable import GameCore

/// Same stub style as GameEngineTests: a fixed dictionary independent of
/// WordEngine.
private struct StubValidator: WordValidating {
    let valid: Set<String>
    func isValidWord(_ word: String) -> Bool { valid.contains(word.uppercased()) }
}

/// Accepts every buildable word. Used where a test only cares about the
/// bonus-word / hint stir extras, not dictionary gating — lets tests spam
/// arbitrary buildable letter combinations without maintaining a word list.
private struct AcceptAllValidator: WordValidating {
    func isValidWord(_ word: String) -> Bool { true }
}

final class StirCurveTests: XCTestCase {
    // MARK: - 4-slot crossword fixture

    /// Wheel PLANETS (7 letters, no repeats) with 4 independent, non-overlapping
    /// slots so each answer can be filled without touching the others.
    private func fourSlotLevel() -> Level {
        let wheel = Wheel(letters: "PLANETS")
        let slots = [
            GridSlot(id: 0, answer: "PLAN", origin: GridCoord(row: 0, col: 0), direction: .across),
            GridSlot(id: 1, answer: "TAPE", origin: GridCoord(row: 1, col: 0), direction: .across),
            GridSlot(id: 2, answer: "NEST", origin: GridCoord(row: 2, col: 0), direction: .across),
            GridSlot(id: 3, answer: "SALT", origin: GridCoord(row: 3, col: 0), direction: .across),
        ]
        return Level(id: "stir-4", wheel: wheel, slots: slots, sceneID: "s", creatureID: "c")
    }

    private func fourSlotEngine() -> GameEngine {
        GameEngine(level: fourSlotLevel(), validator: AcceptAllValidator())
    }

    func testStirTracksGridProgress() {
        let e = fourSlotEngine()
        _ = e.submit("PLAN")
        _ = e.submit("TAPE")
        // 2 of 4 slots solved: 0.85 * 0.5 = 0.425.
        XCTAssertEqual(e.stir, 0.425, accuracy: 0.03)
    }

    func testStirNearlyFullBeforeLastWord() {
        let e = fourSlotEngine()
        _ = e.submit("PLAN")
        _ = e.submit("TAPE")
        _ = e.submit("NEST")
        // 3 of 4 slots solved: 0.85 * 0.75 = 0.6375.
        XCTAssertGreaterThanOrEqual(e.stir, 0.6)
        XCTAssertLessThan(e.stir, 1.0, "the last slot must still be unfilled")
    }

    func testStirNeverExceedsCapBeforeCompletion() {
        let e = fourSlotEngine()
        _ = e.submit("PLAN")
        _ = e.submit("TAPE")
        _ = e.submit("NEST")
        // Spam bonus words: arbitrary 3-letter combinations of PLANETS that
        // are buildable but not any grid answer. 20 * 0.02 = 0.4 extra, which
        // alone would blow past 1.0 without the cap.
        let bonusWords = [
            "PLA", "PLN", "PLE", "PLT", "PLS",
            "PAN", "PAE", "PAT", "PAS", "PNE",
            "PNT", "PNS", "PET", "PES", "PTS",
            "LAN", "LAE", "LAT", "LAS", "LNE",
        ]
        for word in bonusWords {
            _ = e.submit(word)
        }
        // Also spam hints on the one remaining unsolved slot (4 cells max).
        var gen = SeededRandom(seed: 42)
        for _ in 0..<10 {
            _ = e.revealHintCell(using: &gen)
        }
        XCTAssertFalse(e.isComplete, "the last slot was never filled by a matching word")
        XCTAssertLessThanOrEqual(e.stir, 0.95, "stir must stay capped short of the full reveal")
    }

    func testStirIsMonotonic() {
        let e = fourSlotEngine()
        var previous = e.stir
        for word in ["PLAN", "TAPE", "NEST", "SALT"] {
            _ = e.submit(word)
            XCTAssertGreaterThanOrEqual(e.stir, previous, "stir must never regress")
            previous = e.stir
        }
    }

    func testCompletionSnapsToOne() {
        let e = fourSlotEngine()
        _ = e.submit("PLAN")
        _ = e.submit("TAPE")
        _ = e.submit("NEST")
        _ = e.submit("SALT")
        XCTAssertTrue(e.isComplete)
        XCTAssertEqual(e.stir, 1.0, accuracy: 0.0001)
    }

    // MARK: - Pangram-hunt (boss) fixture

    func testBossStirPangramDominates() {
        let level = Level(id: "boss", wheel: Wheel(letters: "STONED"), slots: [],
                          sceneID: "s", creatureID: "c", format: .pangramHunt(target: 4))
        let validator = StubValidator(valid: ["STONED", "STONE", "NODE"])
        let e = GameEngine(level: level, validator: validator)

        _ = e.submit("STONED") // pangram; also the first word toward the target
        // completionFraction = 0.6 (pangram) + 0.4 * (1/4) = 0.7 -> derived 0.595.
        XCTAssertGreaterThanOrEqual(e.stir, 0.85 * 0.6 - 0.01)
        let afterPangram = e.stir

        _ = e.submit("STONE") // second word, not a pangram
        XCTAssertGreaterThan(e.stir, afterPangram, "each additional word should push stir up")
        let afterSecond = e.stir

        _ = e.submit("NODE") // third word
        XCTAssertGreaterThan(e.stir, afterSecond)
        XCTAssertFalse(e.isComplete, "only 3 of the 4 target words have been found")
    }
}
