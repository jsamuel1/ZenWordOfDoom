import Foundation

/// A between-levels "breath": a twisted zen haiku shown over a moving
/// procedural scene, after which a Doom creature pops out (`popoutDelay`
/// seconds in). Keyed by `id`, which matches the level it follows.
public struct CutSceneData: Codable, Sendable {
    public let id: String
    public let scene: String
    public let creature: String
    public let poem: [String]
    public let popoutDelay: Double

    public init(
        id: String,
        scene: String,
        creature: String,
        poem: [String],
        popoutDelay: Double
    ) {
        self.id = id
        self.scene = scene
        self.creature = creature
        self.poem = poem
        self.popoutDelay = popoutDelay
    }
}
