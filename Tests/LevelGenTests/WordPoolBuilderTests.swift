import XCTest
import GameCore
@testable import LevelGen

private struct StubValidator: WordValidating {
    let valid: Set<String>
    func isValidWord(_ word: String) -> Bool { valid.contains(word.uppercased()) }
}

final class WordPoolBuilderTests: XCTestCase {
    private let wheel = Wheel(letters: "STONE")

    func testKeepsBuildableRealModelWordsThenFallback() {
        let out = WordPoolBuilder.merge(
            primary: ["STONE", "NOTES", "ZZZZZ", "QI"],
            fallback: ["TONES", "ONES"],
            wheel: wheel,
            validator: StubValidator(valid: ["STONE", "NOTES"]),
            limit: 10, minLength: 3)
        XCTAssertEqual(out, ["STONE", "NOTES", "TONES", "ONES"])
    }
    func testModelWordRejectedWhenNotValidEvenIfBuildable() {
        let out = WordPoolBuilder.merge(
            primary: ["SNOT"],
            fallback: ["NOTE"],
            wheel: wheel,
            validator: StubValidator(valid: ["NOTE"]),
            limit: 10)
        XCTAssertEqual(out, ["NOTE"])
    }
    func testFallbackNotRevalidated() {
        let out = WordPoolBuilder.merge(
            primary: [], fallback: ["ONSET"],
            wheel: Wheel(letters: "ONSETX"),
            validator: StubValidator(valid: []),
            limit: 10)
        XCTAssertEqual(out, ["ONSET"])
    }
    func testDedupCaseInsensitiveAndCap() {
        let out = WordPoolBuilder.merge(
            primary: ["stone", "STONE"], fallback: ["notes", "tones", "ones"],
            wheel: wheel, validator: StubValidator(valid: ["STONE"]),
            limit: 2)
        XCTAssertEqual(out, ["STONE", "NOTES"])
    }
    func testEmptyPrimaryYieldsFallback() {
        let out = WordPoolBuilder.merge(
            primary: [], fallback: ["NOTE", "TONE"],
            wheel: wheel, validator: StubValidator(valid: []), limit: 10)
        XCTAssertEqual(out, ["NOTE", "TONE"])
    }
    func testModelWordRejectedWhenNotInMainCorpusEvenIfValidAndBuildable() {
        // A validator (or a permissive system dictionary) can claim a made-up
        // word is "valid", but the crossword must only use real words from our
        // bundled main corpus (GeneralWordList) -- the model is never solely
        // trusted for what counts as a real word.
        let out = WordPoolBuilder.merge(
            primary: ["FLIBBER"], // buildable from the wheel below; validator says valid; NOT a real corpus word
            fallback: ["NOTE"],
            wheel: Wheel(letters: "FLIBBERNOTE"), // supplies letters for both FLIBBER and NOTE
            validator: StubValidator(valid: ["FLIBBER", "NOTE"]),
            limit: 10)
        XCTAssertEqual(out, ["NOTE"], "FLIBBER should be rejected: not in GeneralWordList despite passing the validator")
    }
}
