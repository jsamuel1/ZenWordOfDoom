import SwiftUI
import GameCore

/// The letter wheel: tiles arranged on a circle. Tap input is wired now;
/// swipe-to-connect (docs/SPEC.md §5.1) will reuse the same tap targets.
struct WheelView: View {
    let tiles: [LetterTile]
    let selection: [Int]
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2 - 36
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                    let angle = Angle.degrees(Double(index) / Double(tiles.count) * 360 - 90)
                    let pos = CGPoint(
                        x: center.x + radius * CGFloat(cos(angle.radians)),
                        y: center.y + radius * CGFloat(sin(angle.radians))
                    )
                    TileView(
                        letter: tile.letter,
                        order: selectionOrder(of: tile.id),
                        isSelected: selection.contains(tile.id)
                    )
                    .position(pos)
                    .onTapGesture { onTap(tile.id) }
                }
            }
        }
        .frame(height: 240)
    }

    private func selectionOrder(of id: Int) -> Int? {
        selection.firstIndex(of: id).map { $0 + 1 }
    }
}

private struct TileView: View {
    let letter: Character
    let order: Int?
    let isSelected: Bool

    var body: some View {
        Text(String(letter))
            .font(.system(.title, design: .rounded).weight(.bold))
            .frame(width: 56, height: 56)
            .background(
                Circle().fill(isSelected ? Color.accentColor : Color(.sRGB, white: 1, opacity: 0.9))
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(alignment: .topTrailing) {
                if let order {
                    Text("\(order)")
                        .font(.caption2.bold())
                        .padding(4)
                        .background(.black.opacity(0.6), in: Circle())
                        .foregroundStyle(.white)
                        .offset(x: 4, y: -4)
                }
            }
            .shadow(radius: 2)
    }
}
