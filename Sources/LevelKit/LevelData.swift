import Foundation
import GameCore

/// One crossword answer as authored in JSON. `dir` is `"across"` or `"down"`.
public struct SlotData: Codable, Sendable {
    public let id: Int
    public let answer: String
    public let row: Int
    public let col: Int
    public let dir: String

    public init(id: Int, answer: String, row: Int, col: Int, dir: String) {
        self.id = id
        self.answer = answer
        self.row = row
        self.col = col
        self.dir = dir
    }

    /// Convert to a GameCore `GridSlot`. Unknown directions default to `.across`.
    public func toSlot() -> GridSlot {
        let direction: Direction = (dir.lowercased() == "down") ? .down : .across
        return GridSlot(
            id: id,
            answer: answer,
            origin: GridCoord(row: row, col: col),
            direction: direction
        )
    }
}

/// A full level as authored in `levels.json`. `wheel` is an array of
/// single-letter strings; `band` is advisory metadata only (the real band is
/// derived from `wheel.count` by `DifficultyBand`).
public struct LevelData: Codable, Sendable {
    public let id: String
    public let band: String?
    public let wheel: [String]
    public let scene: String
    public let creature: String
    public let slots: [SlotData]

    public init(
        id: String,
        band: String?,
        wheel: [String],
        scene: String,
        creature: String,
        slots: [SlotData]
    ) {
        self.id = id
        self.band = band
        self.wheel = wheel
        self.scene = scene
        self.creature = creature
        self.slots = slots
    }

    /// Build a runtime `Level`. The wheel is assembled by joining the
    /// single-letter entries (`Wheel(letters:)`).
    public func toLevel() -> Level {
        Level(
            id: id,
            wheel: Wheel(letters: wheel.joined()),
            slots: slots.map { $0.toSlot() },
            sceneID: scene,
            creatureID: creature
        )
    }
}
