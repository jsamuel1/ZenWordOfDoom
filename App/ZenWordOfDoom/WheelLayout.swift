import CoreGraphics

/// Pure tile-position geometry for the letter wheel — no SwiftUI dependency,
/// so it's headlessly testable. Two shapes:
///
/// - `.circle` (under 8 tiles): the original evenly-spaced ring.
/// - `.stadium` (8+ tiles): two rows, each itself a shallow arc curving
///   *toward* the other row at its ends (so the whole shape reads as a
///   lens/stadium rather than two flat bars — confirmed via mockup review,
///   design spec §4.3). Row split is even with the remainder on the bottom
///   row (8->4+4, 9->4+5, 10->5+5).
struct WheelLayout: Equatable {
    enum Shape: Equatable { case circle, stadium }

    let center: CGPoint
    /// Meaningful for `.circle` only.
    let radius: CGFloat
    let count: Int
    let shape: Shape
    let tileSize: CGFloat
    /// Meaningful for `.stadium` only: horizontal half-width of each row.
    let rowSpan: CGFloat
    /// Meaningful for `.stadium` only: vertical distance between the two
    /// rows' baselines (before curvature pulls the edges closer together).
    let rowGap: CGFloat
    /// Meaningful for `.stadium` only: how far a row's edge tiles bow toward
    /// the other row, relative to its own baseline.
    let curveDepth: CGFloat

    /// Builds the layout for a given container size, tile count, and the
    /// view's `@ScaledMetric` tile size (before this layout's own cap is
    /// applied — stadium wheels use a tighter cap than the circle's, since
    /// more tiles need to fit in the same space).
    static func make(size: CGSize, count: Int, scaledTileSize: CGFloat) -> WheelLayout {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        if count >= 8 {
            let requested = min(max(scaledTileSize, 44), 64)
            let topCount = count / 2
            let bottomCount = count - topCount
            let rowCount = max(topCount, bottomCount)
            // Screen width doesn't scale with Dynamic Type the way tile size
            // does (only tile size and the wheel's own height share a
            // `@ScaledMetric` factor) -- a narrow-screen device with maximum
            // accessibility text size is a real combination where the
            // requested tile size wouldn't fit `rowCount` tiles across
            // without overlapping. Shrink to what the container can actually
            // fit rather than let tiles overlap; only ever shrinks, never
            // grows beyond what Dynamic Type asked for.
            let widthCap = size.width / (CGFloat(rowCount) + 0.2)
            let heightCap = size.height / 2.5
            let tile = max(min(requested, widthCap, heightCap), 44)
            let rowSpan = max(size.width / 2 - tile * 0.6, 0)
            return WheelLayout(center: center, radius: 0, count: count, shape: .stadium,
                               tileSize: tile, rowSpan: rowSpan, rowGap: tile * 1.5, curveDepth: tile * 0.2)
        } else {
            let tile = min(max(scaledTileSize, 44), 80)
            let radius = max(min(size.width, size.height) / 2 - tile * 0.64, 0)
            return WheelLayout(center: center, radius: radius, count: count, shape: .circle,
                               tileSize: tile, rowSpan: 0, rowGap: 0, curveDepth: 0)
        }
    }

    /// Which row (0 = top, 1 = bottom) a stadium position index belongs to.
    /// Meaningless for `.circle`.
    func row(for index: Int) -> Int {
        index < topCount ? 0 : 1
    }

    private var topCount: Int { count / 2 }

    func position(for index: Int) -> CGPoint {
        switch shape {
        case .circle:
            guard count > 0 else { return center }
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            return CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                           y: center.y + radius * CGFloat(sin(angle)))
        case .stadium:
            let top = topCount
            let isTop = index < top
            let rowCount = isTop ? top : count - top
            let posInRow = isTop ? index : index - top
            let normalizedX: Double = rowCount > 1
                ? (Double(posInRow) / Double(rowCount - 1)) * 2 - 1
                : 0
            let x = center.x + CGFloat(normalizedX) * rowSpan
            let sag = curveDepth * CGFloat(normalizedX * normalizedX)
            let y = isTop ? (center.y - rowGap / 2 + sag) : (center.y + rowGap / 2 - sag)
            return CGPoint(x: x, y: y)
        }
    }

    /// Control point for a curved same-row selection-trail segment: the
    /// straight-line midpoint, pulled toward the gap between the two rows
    /// (down for the top row, up for the bottom row) — the "arcs curving
    /// inward" confirmed via mockup review. Only meaningful for `.stadium`;
    /// callers only invoke this when `row(for:)` agrees for both endpoints.
    func arcControlPoint(from a: Int, to b: Int) -> CGPoint {
        let p1 = position(for: a), p2 = position(for: b)
        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        let bulge = tileSize * 0.6
        let towardCenter: CGFloat = row(for: a) == 0 ? bulge : -bulge
        return CGPoint(x: mid.x, y: mid.y + towardCenter)
    }
}
