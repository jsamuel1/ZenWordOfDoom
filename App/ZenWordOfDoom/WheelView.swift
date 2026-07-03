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
/// `displayOrder` is a permutation of the tile ids that decides where each tile
/// sits around the circle; the Shuffle button re-rolls it. Tiles keep their ids,
/// so a shuffle mid-word doesn't change letters (the owning model cancels any
/// in-progress selection when shuffling).
///
/// This is a dumb, stateless view: it renders from `tiles`/`displayOrder`/
/// `selection` and reports gestures through the callbacks.
struct WheelView: View {
    let tiles: [LetterTile]
    let displayOrder: [Int]
    let selection: [Int]
    let onTap: (Int) -> Void
    let onSwipeBegin: (Int) -> Void
    let onSwipeExtend: (Int) -> Void
    let onSwipeEnd: () -> Void

    /// Diameter of a single tile, scaled with Dynamic Type (clamped so the
    /// touch target never shrinks below 44pt). Fed into `WheelLayout.make`,
    /// which applies its own shape-dependent cap (80pt for `.circle`, under
    /// 8 tiles; 64pt for `.stadium`, 8+ tiles) and shrink-to-fit logic — see
    /// `WheelLayout.swift`.
    @ScaledMetric(relativeTo: .title) private var scaledTileSize: CGFloat = 56
    /// Height of the wheel's frame, scaled with Dynamic Type (never smaller
    /// than the original fixed size). The 350pt cap was originally derived
    /// from the worst case of 9 evenly-spaced tiles on a `.circle` layout;
    /// those tiles now use the `.stadium` layout instead, which fits itself
    /// to the available height via its own width/height caps (see
    /// `WheelLayout.make`). If tiles overlap at extreme accessibility sizes,
    /// re-derive this cap or `WheelLayout`'s stadium tile-size cap.
    @ScaledMetric(relativeTo: .title) private var scaledWheelHeight: CGFloat = 240
    private var wheelHeight: CGFloat { min(max(scaledWheelHeight, 240), 350) }
    /// The tile id currently under the dragging finger (nil when not dragging).
    @State private var activeSwipeTile: Int?
    /// True once a drag has moved far enough to count as a swipe rather than a tap.
    @State private var isSwiping = false
    /// The finger's current location while dragging — the trail's loose end.
    @State private var dragLocation: CGPoint?

    /// Tiles in on-screen order. Falls back to the natural order if `displayOrder`
    /// doesn't cover the tile set (defensive; keeps the wheel intact).
    private var orderedTiles: [LetterTile] {
        let byID = Dictionary(tiles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let ordered = displayOrder.compactMap { byID[$0] }
        return ordered.count == tiles.count ? ordered : tiles
    }

    var body: some View {
        let ordered = orderedTiles
        return GeometryReader { geo in
            let layout = WheelLayout.make(size: geo.size, count: ordered.count, scaledTileSize: scaledTileSize)
            ZStack {
                if layout.shape == .circle {
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                        .frame(width: layout.radius * 2, height: layout.radius * 2)
                        .position(layout.center)
                }

                // The selection trail, drawn under the tiles so it threads
                // through them.
                trailPath(ordered: ordered, layout: layout)
                    .stroke(
                        Color.accentColor.opacity(0.85),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                    .allowsHitTesting(false)

                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, tile in
                    TileView(
                        letter: tile.letter,
                        order: selectionOrder(of: tile.id),
                        isSelected: selection.contains(tile.id),
                        size: layout.tileSize
                    )
                    .position(layout.position(for: index))
                    .onTapGesture { onTap(tile.id) }
                    // VoiceOver activation paths alongside the tap/swipe
                    // gestures above: a named custom action always works,
                    // and the default activation action + isButton trait
                    // make a plain double-tap work too, in case the wheel's
                    // DragGesture ever intercepts the standard activation.
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onTap(tile.id) }
                    .accessibilityAction(named: "Select \(tile.letter)") { onTap(tile.id) }
                    .accessibilityRespondsToUserInteraction(true)
                }
            }
            .contentShape(Rectangle())
            // High priority so the word-trace drag beats the enclosing
            // ScrollView's pan within the wheel's bounds — a plain .gesture
            // would lose swipes with a vertical component to the scroll.
            .highPriorityGesture(swipeGesture(ordered: ordered, layout: layout))
        }
        .frame(height: wheelHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Letter wheel")
        .accessibilityHint("Double-tap a letter to add it to the word. Use the Submit button to submit.")
    }

    // MARK: - Layout

    private func selectionOrder(of id: Int) -> Int? {
        selection.firstIndex(of: id).map { $0 + 1 }
    }

    // MARK: - Selection trail

    /// A polyline through the centers of the selected tiles, in selection order,
    /// continuing to the finger while a drag is in progress. On a stadium wheel,
    /// a segment between two tiles in the *same* row curves inward toward the
    /// gap between rows (§4.3); every other segment (cross-row, or any segment
    /// on a circle wheel) stays a straight line, as before.
    private func trailPath(ordered: [LetterTile], layout: WheelLayout) -> Path {
        Path { path in
            let indices = selection.compactMap { id in ordered.firstIndex(where: { $0.id == id }) }
            guard let first = indices.first else { return }
            path.move(to: layout.position(for: first))
            for (prev, curr) in zip(indices, indices.dropFirst()) {
                let point = layout.position(for: curr)
                if layout.shape == .stadium, layout.row(for: prev) == layout.row(for: curr) {
                    path.addQuadCurve(to: point, control: layout.arcControlPoint(from: prev, to: curr))
                } else {
                    path.addLine(to: point)
                }
            }
            if isSwiping, let drag = dragLocation { path.addLine(to: drag) }
        }
    }

    // MARK: - Swipe hit-testing

    /// A zero-distance drag so the very first touch already hit-tests a tile.
    /// We only treat it as a swipe (firing begin/extend/end) once the finger
    /// actually moves; a touch that never moves falls through to `onTapGesture`.
    private func swipeGesture(ordered: [LetterTile], layout: WheelLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isSwiping {
                    let dx = value.location.x - value.startLocation.x
                    let dy = value.location.y - value.startLocation.y
                    guard (dx * dx + dy * dy) > 36 else { return }
                    isSwiping = true
                }

                dragLocation = value.location

                guard let tile = tile(at: value.location, ordered: ordered, layout: layout) else { return }
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
    private func tile(at point: CGPoint, ordered: [LetterTile], layout: WheelLayout) -> Int? {
        let hitRadius = layout.tileSize / 2
        for (index, tile) in ordered.enumerated() {
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
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size, height: size)
            .background(
                Circle().fill(isSelected ? AccessibilityPalette.wheelTileSelectedFill : AccessibilityPalette.wheelTileFill)
            )
            .foregroundStyle(isSelected ? AccessibilityPalette.wheelTileSelectedText : AccessibilityPalette.wheelTileText)
            .shadow(radius: 2)
            .accessibilityLabel(String(letter))
            .accessibilityValue(order.map { "Selected, position \($0)" } ?? "")
    }
}

#Preview {
    let wheel = SampleLevel.make().wheel
    return WheelView(
        tiles: wheel.tiles,
        displayOrder: wheel.displayOrder(seed: 1),
        selection: [],
        onTap: { _ in },
        onSwipeBegin: { _ in },
        onSwipeExtend: { _ in },
        onSwipeEnd: {}
    )
    .padding()
    .background(Color.black)
}
