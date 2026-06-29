import SwiftUI
import GameCore

/// The letter wheel: tiles arranged on a circle.
///
/// Two input paths share the same circular tile layout:
/// - A plain tap on a tile calls `onTap(tileID)`.
/// - A drag (swipe-to-connect, docs/SPEC.md §5.1) hit-tests the tile positions:
///   the first tile touched fires `onSwipeBegin`, each newly entered tile fires
///   `onSwipeExtend`, and lifting the finger fires `onSwipeEnd`.
///
/// The current selection is drawn as a connecting trail threaded through the
/// chosen tiles (and, while dragging, on to the finger) — the visible path that
/// spells the word. Dragging the finger back along that trail onto the previous
/// tile reverses the last selection (handled by the owning view model).
///
/// This is a dumb, stateless view: it renders from `tiles`/`selection` and
/// reports gestures through the callbacks. The owning view model decides what a
/// tap or swipe means.
struct WheelView: View {
    let tiles: [LetterTile]
    let selection: [Int]
    let onTap: (Int) -> Void
    let onSwipeBegin: (Int) -> Void
    let onSwipeExtend: (Int) -> Void
    let onSwipeEnd: () -> Void

    /// Diameter of a single tile.
    private let tileSize: CGFloat = 56
    /// The tile id currently under the dragging finger (nil when not dragging).
    @State private var activeSwipeTile: Int?
    /// True once a drag has moved far enough to count as a swipe rather than a tap.
    @State private var isSwiping = false
    /// The finger's current location while dragging — the trail's loose end.
    @State private var dragLocation: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let layout = self.layout(in: geo.size)
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 1)
                    .frame(width: layout.radius * 2, height: layout.radius * 2)
                    .position(layout.center)

                // The selection trail, drawn under the tiles so it threads
                // through them. Replaces the old per-tile order badges.
                trailPath(layout: layout)
                    .stroke(
                        Color.accentColor.opacity(0.85),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                    .allowsHitTesting(false)

                ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                    TileView(
                        letter: tile.letter,
                        order: selectionOrder(of: tile.id),
                        isSelected: selection.contains(tile.id),
                        size: tileSize
                    )
                    .position(layout.position(for: index))
                    .onTapGesture { onTap(tile.id) }
                }
            }
            .contentShape(Rectangle())
            .gesture(swipeGesture(layout: layout))
        }
        .frame(height: 240)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Letter wheel")
    }

    // MARK: - Layout

    private struct WheelLayout {
        let center: CGPoint
        let radius: CGFloat
        let count: Int

        func position(for index: Int) -> CGPoint {
            guard count > 0 else { return center }
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            return CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }
    }

    private func layout(in size: CGSize) -> WheelLayout {
        let radius = min(size.width, size.height) / 2 - 36
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return WheelLayout(center: center, radius: max(radius, 0), count: tiles.count)
    }

    private func selectionOrder(of id: Int) -> Int? {
        selection.firstIndex(of: id).map { $0 + 1 }
    }

    // MARK: - Selection trail

    /// A polyline through the centers of the selected tiles, in selection order,
    /// continuing to the finger while a drag is in progress.
    private func trailPath(layout: WheelLayout) -> Path {
        Path { path in
            let points = selection.compactMap { position(ofTileID: $0, layout: layout) }
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            if isSwiping, let drag = dragLocation { path.addLine(to: drag) }
        }
    }

    private func position(ofTileID id: Int, layout: WheelLayout) -> CGPoint? {
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return nil }
        return layout.position(for: index)
    }

    // MARK: - Swipe hit-testing

    /// A zero-distance drag so the very first touch already hit-tests a tile.
    /// We only treat it as a swipe (firing begin/extend/end) once the finger
    /// actually moves; a touch that never moves falls through to `onTapGesture`.
    private func swipeGesture(layout: WheelLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Distinguish a swipe from a stationary tap.
                if !isSwiping {
                    let dx = value.location.x - value.startLocation.x
                    let dy = value.location.y - value.startLocation.y
                    guard (dx * dx + dy * dy) > 36 else { return }
                    isSwiping = true
                }

                // Track the finger so the trail's loose end follows it.
                dragLocation = value.location

                guard let tile = tile(at: value.location, layout: layout) else { return }
                if tile != activeSwipeTile {
                    if activeSwipeTile == nil {
                        onSwipeBegin(tile)
                    } else {
                        onSwipeExtend(tile)
                    }
                    activeSwipeTile = tile
                }
            }
            .onEnded { _ in
                let wasSwiping = isSwiping
                activeSwipeTile = nil
                isSwiping = false
                dragLocation = nil
                if wasSwiping {
                    onSwipeEnd()
                }
            }
    }

    /// Returns the id of the tile whose circular hit area contains `point`.
    private func tile(at point: CGPoint, layout: WheelLayout) -> Int? {
        let hitRadius = tileSize / 2
        for (index, tile) in tiles.enumerated() {
            let pos = layout.position(for: index)
            let dx = point.x - pos.x
            let dy = point.y - pos.y
            if (dx * dx + dy * dy) <= hitRadius * hitRadius {
                return tile.id
            }
        }
        return nil
    }
}

private struct TileView: View {
    let letter: Character
    let order: Int?
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        Text(String(letter))
            .font(.system(.title, design: .rounded).weight(.bold))
            .frame(width: size, height: size)
            .background(
                Circle().fill(isSelected ? Color.accentColor : Color(.sRGB, white: 1, opacity: 0.9))
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .shadow(radius: 2)
            .accessibilityLabel(String(letter))
            // The visible sequence is the trail line; expose the order here so
            // VoiceOver users still hear where each letter falls in the word.
            .accessibilityValue(order.map { "Selected, position \($0)" } ?? "")
    }
}

#Preview {
    WheelView(
        tiles: SampleLevel.make().wheel.tiles,
        selection: [],
        onTap: { _ in },
        onSwipeBegin: { _ in },
        onSwipeExtend: { _ in },
        onSwipeEnd: {}
    )
    .padding()
    .background(Color.black)
}
