import Foundation
import GameCore

/// Greedy, seeded crossword layout. Produces a connected, conflict-free set of
/// interlocking slots. Words that cannot be placed are skipped.
public struct CrosswordLayoutEngine: Sendable {
    public init() {}

    private struct Placement {
        let answer: String
        let origin: GridCoord
        let direction: Direction
        var cells: [GridCoord] {
            (0..<answer.count).map { o in
                direction == .across
                    ? GridCoord(row: origin.row, col: origin.col + o)
                    : GridCoord(row: origin.row + o, col: origin.col)
            }
        }
    }

    public func layout(words rawWords: [String], maxSlots: Int, seed: UInt64) -> [GridSlot] {
        let words = rawWords
            .map { $0.uppercased() }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }
        guard let first = words.first else { return [] }

        var rng = SeededRandom(seed: seed)
        var placed: [Placement] = [Placement(answer: first, origin: GridCoord(row: 0, col: 0), direction: .across)]
        var occupied: [GridCoord: Character] = [:]
        for (i, c) in Array(first).enumerated() { occupied[GridCoord(row: 0, col: i)] = c }

        for word in words.dropFirst() {
            if placed.count >= maxSlots { break }
            let options = placements(for: word, given: occupied)
            guard !options.isEmpty else { continue }
            let choice = options[Int(rng.next() % UInt64(options.count))]
            placed.append(choice)
            for (i, c) in Array(word).enumerated() { occupied[choice.cells[i]] = c }
        }
        return normalize(placed)
    }

    private func placements(for word: String, given occupied: [GridCoord: Character]) -> [Placement] {
        var result: [Placement] = []
        let chars = Array(word)
        for (cell, letter) in occupied {
            for (i, c) in chars.enumerated() where c == letter {
                for dir in [Direction.across, Direction.down] {
                    let origin = dir == .across
                        ? GridCoord(row: cell.row, col: cell.col - i)
                        : GridCoord(row: cell.row - i, col: cell.col)
                    let p = Placement(answer: word, origin: origin, direction: dir)
                    if isValid(p, given: occupied) { result.append(p) }
                }
            }
        }
        // De-duplicate identical placements (same origin + direction + answer)
        var seen = Set<String>()
        result = result.filter { p in
            let key = "\(p.answer)|\(p.origin.row),\(p.origin.col)|\(p.direction.rawValue)"
            return seen.insert(key).inserted
        }
        return result.sorted {
            ($0.origin.row, $0.origin.col, $0.direction.rawValue)
                < ($1.origin.row, $1.origin.col, $1.direction.rawValue)
        }
    }

    private func isValid(_ p: Placement, given occupied: [GridCoord: Character]) -> Bool {
        let chars = Array(p.answer)
        var crossings = 0
        let before = p.direction == .across
            ? GridCoord(row: p.origin.row, col: p.origin.col - 1)
            : GridCoord(row: p.origin.row - 1, col: p.origin.col)
        let lastCell = p.cells.last!
        let after = p.direction == .across
            ? GridCoord(row: lastCell.row, col: lastCell.col + 1)
            : GridCoord(row: lastCell.row + 1, col: lastCell.col)
        if occupied[before] != nil || occupied[after] != nil { return false }

        for (i, cell) in p.cells.enumerated() {
            if let existing = occupied[cell] {
                if existing != chars[i] { return false }
                crossings += 1
            } else {
                let perp: [GridCoord] = p.direction == .across
                    ? [GridCoord(row: cell.row - 1, col: cell.col), GridCoord(row: cell.row + 1, col: cell.col)]
                    : [GridCoord(row: cell.row, col: cell.col - 1), GridCoord(row: cell.row, col: cell.col + 1)]
                if perp.contains(where: { occupied[$0] != nil }) { return false }
            }
        }
        return crossings >= 1
    }

    private func normalize(_ placed: [Placement]) -> [GridSlot] {
        let allCells = placed.flatMap(\.cells)
        let minRow = allCells.map(\.row).min() ?? 0
        let minCol = allCells.map(\.col).min() ?? 0
        return placed.enumerated().map { idx, p in
            GridSlot(
                id: idx,
                answer: p.answer,
                origin: GridCoord(row: p.origin.row - minRow, col: p.origin.col - minCol),
                direction: p.direction
            )
        }
    }
}
