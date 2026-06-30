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
}
