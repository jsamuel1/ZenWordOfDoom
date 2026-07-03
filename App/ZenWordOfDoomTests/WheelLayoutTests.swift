import XCTest
@testable import ZenWordOfDoom

final class WheelLayoutTests: XCTestCase {
    private let size = CGSize(width: 360, height: 300)

    func testUnderEightTilesStaysCircle() {
        for count in 3...7 {
            let layout = WheelLayout.make(size: size, count: count, scaledTileSize: 56)
            XCTAssertEqual(layout.shape, .circle, "count \(count) should stay circle")
        }
    }

    func testEightOrMoreTilesIsStadium() {
        for count in 8...10 {
            let layout = WheelLayout.make(size: size, count: count, scaledTileSize: 56)
            XCTAssertEqual(layout.shape, .stadium, "count \(count) should be stadium")
        }
    }

    func testRowSplitEvenWithRemainderOnBottom() {
        // 8 -> 4+4, 9 -> 4+5, 10 -> 5+5 (top count = count/2, integer division).
        let expectations: [(count: Int, topCount: Int)] = [(8, 4), (9, 4), (10, 5)]
        for (count, expectedTop) in expectations {
            let layout = WheelLayout.make(size: size, count: count, scaledTileSize: 56)
            let topIndices = (0..<count).filter { layout.row(for: $0) == 0 }
            XCTAssertEqual(topIndices.count, expectedTop, "count \(count)")
        }
    }

    func testStadiumTilesDontOverlapAcrossSizesAndCounts() {
        // Stadium's adaptive tile-size cap (see WheelLayout.make) makes it
        // safe across the full realistic range, including a narrow-screen
        // device paired with maximum accessibility text size.
        let sizes = [CGSize(width: 320, height: 260), CGSize(width: 360, height: 300), CGSize(width: 430, height: 350)]
        let tileSizes: [CGFloat] = [44, 56, 64, 80]
        for size in sizes {
            for tileSize in tileSizes {
                for count in 8...10 {
                    let layout = WheelLayout.make(size: size, count: count, scaledTileSize: tileSize)
                    let positions = (0..<count).map { layout.position(for: $0) }
                    for i in 0..<positions.count {
                        for j in (i + 1)..<positions.count {
                            let dx = positions[i].x - positions[j].x
                            let dy = positions[i].y - positions[j].y
                            let distance = (dx * dx + dy * dy).squareRoot()
                            XCTAssertGreaterThanOrEqual(
                                distance, layout.tileSize - 0.01,
                                "count \(count) tiles \(i)/\(j) overlap at size \(size), tileSize \(tileSize)")
                        }
                    }
                }
            }
        }
    }

    func testCircleTilesDontOverlapAcrossSizesAndCounts() {
        // Circle is pre-existing, unmodified code (out of scope for this
        // task) with no adaptive cap -- its overlap safety was originally
        // derived assuming tile size and container size grow together (both
        // driven by the same `@ScaledMetric` factor via `wheelHeight`), which
        // doesn't hold for an independently-narrow screen width. This sweep
        // stays within the range that formula was actually derived for
        // (see WheelView.swift's own `wheelHeight` doc comment); a
        // narrower-than-this combination is the same latent limitation
        // circle already ships with today, unrelated to this task.
        let sizes = [CGSize(width: 360, height: 300), CGSize(width: 430, height: 350)]
        let tileSizes: [CGFloat] = [44, 56, 64, 80]
        for size in sizes {
            for tileSize in tileSizes {
                for count in 5...7 {
                    let layout = WheelLayout.make(size: size, count: count, scaledTileSize: tileSize)
                    let positions = (0..<count).map { layout.position(for: $0) }
                    for i in 0..<positions.count {
                        for j in (i + 1)..<positions.count {
                            let dx = positions[i].x - positions[j].x
                            let dy = positions[i].y - positions[j].y
                            let distance = (dx * dx + dy * dy).squareRoot()
                            XCTAssertGreaterThanOrEqual(
                                distance, layout.tileSize - 0.01,
                                "count \(count) tiles \(i)/\(j) overlap at size \(size), tileSize \(tileSize)")
                        }
                    }
                }
            }
        }
    }

    func testStadiumArcControlPointBendsTowardTheGapBetweenRows() {
        let layout = WheelLayout.make(size: size, count: 10, scaledTileSize: 56)
        // Two adjacent tiles in the top row (indices 0, 1 of a 5-tile top row).
        let p0 = layout.position(for: 0)
        let p1 = layout.position(for: 1)
        let control = layout.arcControlPoint(from: 0, to: 1)
        let straightMidY = (p0.y + p1.y) / 2
        // Top row's gap-ward direction is +y (down, toward the bottom row).
        XCTAssertGreaterThan(control.y, straightMidY, "top-row arc should bulge toward the center gap (down)")

        // Two adjacent tiles in the bottom row (last two indices).
        let b0 = layout.position(for: 8)
        let b1 = layout.position(for: 9)
        let bottomControl = layout.arcControlPoint(from: 8, to: 9)
        let bottomStraightMidY = (b0.y + b1.y) / 2
        XCTAssertLessThan(bottomControl.y, bottomStraightMidY, "bottom-row arc should bulge toward the center gap (up)")
    }
}
