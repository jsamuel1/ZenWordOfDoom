import Foundation

/// How a level is played. Zen has no clock; Doom races a timer toward the creature.
public enum GameMode: Equatable, Sendable {
    case zen
    case doom(timeLimit: TimeInterval)
}
