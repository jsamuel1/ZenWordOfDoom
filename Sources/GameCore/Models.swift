import Foundation

/// A single playable letter on the wheel. `id` is stable per level so that
/// duplicate letters (e.g. two `E`s) are distinct, selectable tiles.
public struct LetterTile: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: Int
    public let letter: Character

    public init(id: Int, letter: Character) {
        self.id = id
        self.letter = Character(String(letter).uppercased())
    }
}

/// The wheel of 5...9 letters. `size` is the maximum word length, N.
public struct Wheel: Equatable, Sendable {
    public let tiles: [LetterTile]

    public init(tiles: [LetterTile]) {
        self.tiles = tiles
    }

    /// Convenience: build a wheel from a string, assigning sequential ids.
    public init(letters: String) {
        self.tiles = letters.uppercased().enumerated().map { idx, ch in
            LetterTile(id: idx, letter: ch)
        }
    }

    public var size: Int { tiles.count }

    public var multiset: LetterMultiset { LetterMultiset(tiles.map(\.letter)) }
}

public enum Direction: String, Codable, Sendable {
    case across
    case down
}

public struct GridCoord: Hashable, Codable, Sendable {
    public let row: Int
    public let col: Int
    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

/// A crossword answer slot. `answer` is hidden from the player until found.
public struct GridSlot: Identifiable, Equatable, Sendable {
    public let id: Int
    public let answer: String
    public let origin: GridCoord
    public let direction: Direction

    public init(id: Int, answer: String, origin: GridCoord, direction: Direction) {
        self.id = id
        self.answer = answer.uppercased()
        self.origin = origin
        self.direction = direction
    }

    /// Ordered cells this answer occupies.
    public var cells: [GridCoord] {
        (0..<answer.count).map { offset in
            switch direction {
            case .across: return GridCoord(row: origin.row, col: origin.col + offset)
            case .down:   return GridCoord(row: origin.row + offset, col: origin.col)
            }
        }
    }
}

public enum DifficultyBand: String, Codable, Sendable {
    case easy, medium, hard, expert, master

    public init(wheelSize: Int) {
        switch wheelSize {
        case ...5: self = .easy
        case 6:    self = .medium
        case 7:    self = .hard
        case 8:    self = .expert
        default:   self = .master
        }
    }
}

/// A fully specified, validated level.
public struct Level: Identifiable, Sendable {
    public let id: String
    public let wheel: Wheel
    public let slots: [GridSlot]
    public let sceneID: String
    public let creatureID: String

    public init(id: String, wheel: Wheel, slots: [GridSlot], sceneID: String, creatureID: String) {
        self.id = id
        self.wheel = wheel
        self.slots = slots
        self.sceneID = sceneID
        self.creatureID = creatureID
    }

    public var band: DifficultyBand { DifficultyBand(wheelSize: wheel.size) }
}
