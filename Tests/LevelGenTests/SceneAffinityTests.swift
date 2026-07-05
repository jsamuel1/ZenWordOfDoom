import XCTest
import GameCore
@testable import LevelGen

final class SceneAffinityTests: XCTestCase {
    func testTagsSplitSlugWords() {
        XCTAssertEqual(SceneAffinity.tags(forSlug: "moss-garden"), ["MOSS", "GARDEN"])
        XCTAssertEqual(SceneAffinity.tags(forSlug: "still-pond"), ["STILL", "POND"])
        XCTAssertEqual(SceneAffinity.tags(forSlug: "single"), ["SINGLE"])
        XCTAssertEqual(SceneAffinity.tags(forSlug: ""), [])
    }

    func testBuildableTagOutscoresMereOverlap() {
        // GARNISHED contains all of GARDEN's letters; BRIMSTONE only overlaps.
        let strong = SceneAffinity.score(anchor: "GARNISHED", slug: "moss-garden")
        let weak = SceneAffinity.score(anchor: "BRIMSTONE", slug: "moss-garden")
        XCTAssertGreaterThan(strong, weak)
        XCTAssertGreaterThanOrEqual(weak, 0)
    }

    func testScoreIsDeterministicAndCaseInsensitive() {
        XCTAssertEqual(
            SceneAffinity.score(anchor: "garnished", slug: "moss-garden"),
            SceneAffinity.score(anchor: "GARNISHED", slug: "moss-garden")
        )
    }
}
