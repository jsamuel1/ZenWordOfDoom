import Foundation

/// A themed grouping of levels surfaced in the level-select screen.
public struct PackData: Codable, Sendable {
    public let id: String
    public let title: String
    public let scene: String
    public let creature: String
    public let levelIDs: [String]

    public init(
        id: String,
        title: String,
        scene: String,
        creature: String,
        levelIDs: [String]
    ) {
        self.id = id
        self.title = title
        self.scene = scene
        self.creature = creature
        self.levelIDs = levelIDs
    }
}
