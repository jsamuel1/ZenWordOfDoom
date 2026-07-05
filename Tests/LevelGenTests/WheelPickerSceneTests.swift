import XCTest
@testable import LevelGen
import GameCore

final class WheelPickerSceneTests: XCTestCase {
    func testSceneWheelComesFromTheKnownGoodPool() throws {
        let wheel = try WheelPicker.wheel(sceneID: "still-pond", theme: .zen, band: .medium, index: 0)
        XCTAssertEqual(wheel.size, 6)
        let signature = String(wheel.tiles.map(\.letter)).sorted()
        let poolSignatures = AnchorPools.shared.anchors(ofLength: 6).map { $0.sorted() }
        XCTAssertTrue(poolSignatures.contains(signature),
                      "wheel letters must be a known-good length-6 anchor")
    }

    func testUnknownSceneStillYieldsAValidWheel() throws {
        // Affinity handles any slug (letter overlap), so even an unmapped
        // scene draws a quality-gated wheel of the right size.
        let wheel = try WheelPicker.wheel(sceneID: "no-such-scene", theme: .zen, band: .medium, index: 3)
        XCTAssertEqual(wheel.size, 6)
    }

    func testDeterministic() throws {
        let a = try WheelPicker.wheel(sceneID: "still-pond", theme: .zen, band: .hard, index: 7)
        let b = try WheelPicker.wheel(sceneID: "still-pond", theme: .zen, band: .hard, index: 7)
        XCTAssertEqual(String(a.tiles.map(\.letter)), String(b.tiles.map(\.letter)))
    }

    func testConsecutiveIndexesNeverRepeatAWheel() throws {
        // The scene cycles through `affinityCandidates` distinct anchors, so
        // same-scene same-band levels at adjacent orders always differ.
        for index in 0..<30 {
            let a = try WheelPicker.wheel(sceneID: "moss-garden", theme: .zen, band: .master, index: index)
            let b = try WheelPicker.wheel(sceneID: "moss-garden", theme: .zen, band: .master, index: index + 1)
            XCTAssertNotEqual(String(a.tiles.map(\.letter)).sorted(),
                              String(b.tiles.map(\.letter)).sorted(),
                              "indexes \(index)/\(index + 1) repeated a wheel")
        }
    }

    func testSceneCyclesThroughManyDistinctWheels() throws {
        var signatures = Set<String>()
        for index in 0..<WheelPicker.affinityCandidates {
            let wheel = try WheelPicker.wheel(sceneID: "ember-catacomb", theme: .doom, band: .master, index: index)
            signatures.insert(String(String(wheel.tiles.map(\.letter)).sorted()))
        }
        XCTAssertEqual(signatures.count, WheelPicker.affinityCandidates,
                       "one full cycle should visit every candidate exactly once")
    }

    func testTiersDrawDisjointWheels() throws {
        // Tier bins are disjoint richness ranges, so the same (scene, band,
        // index) at easy vs hard tier must deal different letters.
        for index in 0..<8 {
            let easy = try WheelPicker.wheel(sceneID: "still-pond", theme: .zen, band: .medium,
                                             index: index, tier: .easy)
            let hard = try WheelPicker.wheel(sceneID: "still-pond", theme: .zen, band: .medium,
                                             index: index, tier: .hard)
            XCTAssertNotEqual(String(easy.tiles.map(\.letter)).sorted(),
                              String(hard.tiles.map(\.letter)).sorted(),
                              "index \(index): easy and hard tier dealt the same wheel")
        }
    }
}
