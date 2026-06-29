import SwiftUI
import GameCore

/// The crossword grid. Cells that belong to a slot are shown; filled cells
/// reveal their letter. Blank board cells are not drawn.
struct GridView: View {
    let level: Level
    let filledCells: [GridCoord: Character]

    private var occupiedCells: Set<GridCoord> {
        Set(level.slots.flatMap(\.cells))
    }

    private var bounds: (rows: Int, cols: Int) {
        let cells = occupiedCells
        let maxRow = cells.map(\.row).max() ?? 0
        let maxCol = cells.map(\.col).max() ?? 0
        return (maxRow + 1, maxCol + 1)
    }

    var body: some View {
        let (rows, cols) = bounds
        let occupied = occupiedCells
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { c in
                        let coord = GridCoord(row: r, col: c)
                        cell(at: coord, occupied: occupied.contains(coord))
                    }
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func cell(at coord: GridCoord, occupied: Bool) -> some View {
        if occupied {
            let letter = filledCells[coord]
            RoundedRectangle(cornerRadius: 6)
                .fill(letter == nil ? Color.white.opacity(0.5) : Color.white)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let letter {
                        Text(String(letter))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.black)
                    }
                }
        } else {
            Color.clear.aspectRatio(1, contentMode: .fit)
        }
    }
}
