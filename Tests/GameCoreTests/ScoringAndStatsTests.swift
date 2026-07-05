import XCTest
@testable import GameCore

/// Minimal validator so these tests stay independent of the real dictionary
/// validator (`SystemDictionary`/`UITextChecker`).
private struct StubValidator: WordValidating {
    let valid: Set<String>
    func isValidWord(_ word: String) -> Bool { valid.contains(word.uppercased()) }
}

final class ScoringAndStatsTests: XCTestCase {

    private func engine(mode: GameMode = .zen) -> GameEngine {
        let validator = StubValidator(valid: ["STONE", "NODE", "DOTS", "NOTE", "STONED", "TENS"])
        return GameEngine(level: SampleLevel.make(), validator: validator, mode: mode)
    }

    // MARK: - Scoring

    func testWordScoreGrowsWithLength() {
        let short = Scoring.wordScore(length: 3, isPangram: false)
        let long = Scoring.wordScore(length: 5, isPangram: false)
        XCTAssertGreaterThan(long, short)
    }

    func testPangramBonusAddsToScore() {
        let plain = Scoring.wordScore(length: 6, isPangram: false)
        let pangram = Scoring.wordScore(length: 6, isPangram: true)
        XCTAssertEqual(pangram - plain, 50)
    }

    func testBonusScoreSmallerThanGridWord() {
        XCTAssertLessThan(Scoring.bonusScore(length: 5),
                          Scoring.wordScore(length: 5, isPangram: false))
    }

    func testZeroLengthScoresZero() {
        XCTAssertEqual(Scoring.wordScore(length: 0, isPangram: true), 0)
        XCTAssertEqual(Scoring.bonusScore(length: 0), 0)
    }

    func testEngineAccumulatesScoreOnGridWord() {
        let e = engine()
        XCTAssertEqual(e.score, 0)
        _ = e.submit("STONE")
        XCTAssertEqual(e.score, Scoring.wordScore(length: 5, isPangram: false))
    }

    func testEngineAddsBonusScoreForBonusWord() {
        let e = engine()
        _ = e.submit("NOTE") // valid, buildable, not a grid answer
        XCTAssertEqual(e.score, Scoring.bonusScore(length: 4))
    }

    // MARK: - Pangram

    func testIsPangramWhenWordSpansWheel() {
        let e = engine()
        // Wheel STONED has size 6; STONED uses all six letters.
        XCTAssertTrue(e.isPangram("STONED"))
        XCTAssertFalse(e.isPangram("STONE"))
    }

    func testPangramCountAndScoreOnSubmit() {
        let e = engine()
        _ = e.submit("STONED") // bonus word (not a grid answer) and a pangram
        XCTAssertEqual(e.pangramCount, 1)
        // It's a bonus word, so scored via bonusScore.
        XCTAssertEqual(e.score, Scoring.bonusScore(length: 6))
    }

    // MARK: - Mode

    func testDefaultInitializerIsZenMode() {
        let validator = StubValidator(valid: [])
        XCTAssertEqual(GameEngine(level: SampleLevel.make(), validator: validator).mode, .zen)
    }

    func testDoomModeStored() {
        let e = engine(mode: .doom(timeLimit: 90))
        XCTAssertEqual(e.mode, .doom(timeLimit: 90))
    }

    // MARK: - Seeded RNG determinism

    func testSeededRandomIsDeterministic() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        let seqA = (0..<10).map { _ in a.next() }
        let seqB = (0..<10).map { _ in b.next() }
        XCTAssertEqual(seqA, seqB)
    }

    func testSeededRandomDiffersBySeed() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    // MARK: - Hint reveal

    func testRevealHintFillsACellDeterministically() {
        let e1 = engine()
        let e2 = engine()
        var g1 = SeededRandom(seed: 7)
        var g2 = SeededRandom(seed: 7)
        let r1 = e1.revealHintCell(using: &g1)
        let r2 = e2.revealHintCell(using: &g2)
        XCTAssertNotNil(r1)
        XCTAssertEqual(r1?.0, r2?.0)
        XCTAssertEqual(r1?.1, r2?.1)
        // The revealed cell is now present in filledCells.
        if let (coord, letter) = r1 {
            XCTAssertEqual(e1.filledCells[coord], letter)
        }
    }

    func testRevealHintReturnsNilWhenNothingLeft() {
        let e = engine()
        _ = e.submit("STONE")
        _ = e.submit("NODE")
        _ = e.submit("DOTS")
        XCTAssertTrue(e.isComplete)
        var g = SeededRandom(seed: 3)
        XCTAssertNil(e.revealHintCell(using: &g))
    }

    func testRevealHintDoesNotOverfillBeyondGrid() {
        let e = engine()
        var g = SeededRandom(seed: 11)
        // Reveal cells repeatedly; should never exceed total occupied cells and
        // eventually return nil once everything is filled.
        var reveals = 0
        while e.revealHintCell(using: &g) != nil {
            reveals += 1
            XCTAssertLessThan(reveals, 100, "hint reveal did not terminate")
        }
        XCTAssertGreaterThan(reveals, 0)
    }

    // MARK: - GameStats

    func testGameStatsStartsZeroed() {
        let s = GameStats()
        XCTAssertEqual(s.levelsCleared, 0)
        XCTAssertEqual(s.totalWordsFound, 0)
        XCTAssertEqual(s.totalBonusWords, 0)
        XCTAssertEqual(s.longestWord, "")
        XCTAssertEqual(s.pangrams, 0)
        XCTAssertEqual(s.creaturesRevealed, 0)
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(s.bestStreak, 0)
    }

    func testRecordWordTracksLongestAndCounts() {
        var s = GameStats()
        s.recordWord("DOT", isBonus: true, isPangram: false)
        s.recordWord("STONED", isBonus: false, isPangram: true)
        XCTAssertEqual(s.totalWordsFound, 2)
        XCTAssertEqual(s.totalBonusWords, 1)
        XCTAssertEqual(s.pangrams, 1)
        XCTAssertEqual(s.longestWord, "STONED")
    }

    func testRecordClearCountsLevels() {
        var s = GameStats()
        s.recordClear()
        s.recordClear()
        XCTAssertEqual(s.levelsCleared, 2)
        // Clears no longer drive the streak (that's daily now).
        XCTAssertEqual(s.currentStreak, 0)
    }

    func testDailyStreakAdvancesResetsAndIsIdempotent() {
        var s = GameStats()
        s.recordPlay(dayNumber: 100)
        XCTAssertEqual(s.currentStreak, 1)
        s.recordPlay(dayNumber: 100)          // same day: no change
        XCTAssertEqual(s.currentStreak, 1)
        s.recordPlay(dayNumber: 101)          // consecutive: +1
        XCTAssertEqual(s.currentStreak, 2)
        s.recordPlay(dayNumber: 105)          // gap: reset to 1
        XCTAssertEqual(s.currentStreak, 1)
        XCTAssertEqual(s.bestStreak, 2)
    }

    func testSaveStateRoundTrips() throws {
        var state = SaveState()
        state.serenity = 30
        state.stats.recordClear()
        state.progress["garden-001"] = LevelProgress(levelID: "garden-001", cleared: true, bestScore: 120, bonusWordsFound: 2, noHint: true)
        state.bestiary["rock-oni"] = BestiaryEntry(creatureID: "rock-oni", firstRevealedLevelID: "garden-001")

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SaveState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testEmptySaveStateDefaults() {
        let s = SaveState()
        XCTAssertEqual(s.serenity, Economy.startingSerenity)
        XCTAssertTrue(s.progress.isEmpty)
        XCTAssertTrue(s.bestiary.isEmpty)
        XCTAssertEqual(s.stats, GameStats())
    }
}
