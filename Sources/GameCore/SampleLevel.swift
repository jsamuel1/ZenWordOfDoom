import Foundation

/// A hand-authored sample level used by the app shell and tests.
/// Wheel STONED (6 letters → medium). Three answers interlock cleanly:
///
///   col:  0 1 2 3 4 5 6
/// row0    S T O N E          STONE across @ (0,0)
/// row1          O            NODE  down   @ (0,3), shares N at (0,3)
/// row2          D O T S      DOTS  across @ (2,3), shares D at (2,3)
/// row3          E
///
/// Shared cells: (0,3)=N for STONE∩NODE, (2,3)=D for NODE∩DOTS. No conflicts.
public enum SampleLevel {
    public static func make() -> Level {
        let wheel = Wheel(letters: "STONED")
        let slots = [
            GridSlot(id: 0, answer: "STONE", origin: GridCoord(row: 0, col: 0), direction: .across),
            GridSlot(id: 1, answer: "NODE",  origin: GridCoord(row: 0, col: 3), direction: .down),
            GridSlot(id: 2, answer: "DOTS",  origin: GridCoord(row: 2, col: 3), direction: .across),
        ]
        return Level(
            id: "garden-001",
            wheel: wheel,
            slots: slots,
            sceneID: "sand-garden",
            creatureID: "rock-oni"
        )
    }
}
