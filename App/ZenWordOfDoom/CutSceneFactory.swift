import Foundation
import LevelKit
import LevelGen

/// Builds a between-levels "breath" for a procedurally generated level. The
/// scene/creature come from the just-cleared level; the poem is a short themed
/// couplet chosen deterministically from the id's play order.
enum CutSceneFactory {
    static func cutScene(forLevelID id: String,
                         theme: Theme,
                         order: Int,
                         sceneID: String,
                         creatureID: String) -> CutSceneData {
        let poems = theme == .zen ? zenPoems : doomPoems
        let poem = poems[((order % poems.count) + poems.count) % poems.count]
        return CutSceneData(id: id, scene: sceneID, creature: creatureID,
                            poem: poem, popoutDelay: theme == .zen ? 2.4 : 1.6)
    }

    private static let zenPoems: [[String]] = [
        ["still water holds", "the whole sky —", "then a ripple"],
        ["one breath in,", "the garden", "lets you go"],
        ["moss on old stone,", "patient as", "the morning"],
    ]
    private static let doomPoems: [[String]] = [
        ["the calm was bait —", "something below", "uncoils"],
        ["you spelled the words;", "the dark", "spelled you"],
        ["peace is a mask", "the abyss", "wears well"],
    ]
}
