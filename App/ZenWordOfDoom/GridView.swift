import SwiftUI
import GameCore

/// The crossword grid. Only cells that belong to a slot are drawn; blank board
/// cells are left transparent. Filled cells reveal their letter, and cells that
/// belong to a solved slot are tinted to mark completion.
///
/// Stateless: rendered entirely from `level`, `filledCells`, and `solvedSlotIDs`.
struct GridView: View {
    let level: Level
    let filledCells: [GridCoord: Character]
    let solvedSlotIDs: Set<Int>

    /// All grid coordinates that belong to at least one slot.
    private var occupiedCells: Set<GridCoord> {
        Set(level.slots.flatMap(\.cells))
    }

    /// Coordinates belonging to a solved slot (for tinting).
    private var solvedCells: Set<GridCoord> {
        Set(level.slots
            .filter { solvedSlotIDs.contains($0.id) }
            .flatMap(\.cells))
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
        let solved = solvedCells
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { c in
                        let coord = GridCoord(row: r, col: c)
                        cell(
                            at: coord,
                            occupied: occupied.contains(coord),
                            solved: solved.contains(coord)
                        )
                    }
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Crossword grid")
    }

    @ViewBuilder
    private func cell(at coord: GridCoord, occupied: Bool, solved: Bool) -> some View {
        if occupied {
            let letter = filledCells[coord]
            RoundedRectangle(cornerRadius: 6)
                .fill(fillColor(letter: letter, solved: solved))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let letter {
                        Text(String(letter))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(solved ? AccessibilityPalette.gridSolvedText : AccessibilityPalette.gridFilledText)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                }
                // Rendered exactly as the palette constant — no extra opacity —
                // so the on-screen stroke matches what WCAGContrastTests pins.
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AccessibilityPalette.gridCellStroke, lineWidth: 1)
                )
        } else {
            Color.clear.aspectRatio(1, contentMode: .fit)
        }
    }

    /// These fills sit on light cells within the grid's `.ultraThinMaterial`
    /// background — see `AccessibilityPalette.relativeLuminance` for the
    /// "composite over white" approximation this depends on.
    private func fillColor(letter: Character?, solved: Bool) -> Color {
        if solved {
            return AccessibilityPalette.gridSolvedFill
        }
        return letter == nil ? AccessibilityPalette.gridUnfilledFill : AccessibilityPalette.gridFilledFill
    }
}

#Preview {
    GridView(
        level: SampleLevel.make(),
        filledCells: [GridCoord(row: 0, col: 0): "S", GridCoord(row: 0, col: 1): "T"],
        solvedSlotIDs: []
    )
    .padding()
    .background(Color.black)
}
