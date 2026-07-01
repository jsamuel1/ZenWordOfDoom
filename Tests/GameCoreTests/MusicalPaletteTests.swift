import XCTest
@testable import GameCore

final class MusicalPaletteTests: XCTestCase {
    func testZenAtZeroStirIsCalm() {
        let p = MusicalPalette.palette(for: .zen, stir: 0)
        XCTAssertEqual(p.edge, 0, accuracy: 0.0001)
        XCTAssertEqual(p.root, MusicalPalette.zen.root, accuracy: 0.0001)
        XCTAssertEqual(p.scale, MusicalPalette.zen.scale)
    }

    func testStirPushesZenTowardDoom() {
        let calm = MusicalPalette.palette(for: .zen, stir: 0)
        let full = MusicalPalette.palette(for: .zen, stir: 1)
        XCTAssertGreaterThan(full.edge, calm.edge)          // harsher
        XCTAssertLessThan(full.root, calm.root)             // sinks in pitch
        XCTAssertGreaterThan(full.droneLevel, calm.droneLevel)
        XCTAssertEqual(full.scale, MusicalPalette.doom.scale, "high stir flips to the doom scale")
    }

    func testDoomBaseStartsDarkerThanZen() {
        let zen0 = MusicalPalette.palette(for: .zen, stir: 0)
        let doom0 = MusicalPalette.palette(for: .doom, stir: 0)
        XCTAssertGreaterThan(doom0.edge, zen0.edge)
        XCTAssertLessThan(doom0.root, zen0.root)
    }

    func testEdgeNeverExceedsOne() {
        for stir in stride(from: 0.0, through: 1.0, by: 0.1) {
            XCTAssertLessThanOrEqual(MusicalPalette.palette(for: .zen, stir: stir).edge, 1)
            XCTAssertLessThanOrEqual(MusicalPalette.palette(for: .doom, stir: stir).edge, 1)
        }
    }

    func testFrequencyRootAndOctave() {
        let p = MusicalPalette.zen
        XCTAssertEqual(p.frequency(degree: 0), p.root, accuracy: 0.001)
        // One full scale up is an octave (×2).
        XCTAssertEqual(p.frequency(degree: p.scale.count), p.root * 2, accuracy: 0.001)
        // Negative degrees drop an octave.
        XCTAssertEqual(p.frequency(degree: -p.scale.count), p.root / 2, accuracy: 0.001)
    }
}
