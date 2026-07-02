import Foundation
import GameCore
import LevelGen

/// Builds a between-levels "breath" for a procedurally generated level. The
/// scene/creature come from the just-cleared level; the poem is a short themed
/// couplet chosen deterministically from the id's play order.
enum CutSceneFactory {
    static func cutScene(forLevelID id: String,
                         theme: Theme,
                         order: Int,
                         sceneID: String,
                         creatureID: String,
                         poemSet: String? = nil) -> CutSceneData {
        let poems = pool(poemSet: poemSet, theme: theme)
        let poem = poems[((order % poems.count) + poems.count) % poems.count]
        return CutSceneData(id: id, scene: sceneID, creature: creatureID,
                            poem: poem, popoutDelay: theme == .zen ? 2.4 : 1.6)
    }

    /// The equipped Shrine poem set replaces the default themed pool; unknown
    /// or nil ids fall back to the built-in verses.
    private static func pool(poemSet: String?, theme: Theme) -> [[String]] {
        switch poemSet {
        case "poems-deep": return deepPoems
        case "poems-dawn": return dawnPoems
        default: return theme == .zen ? zenPoems : doomPoems
        }
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

    // MARK: Shrine poem sets

    private static let deepPoems: [[String]] = [
        ["fathoms keep count", "of every word", "you owe"],
        ["the tide returns", "what the tide", "was given"],
        ["below the koi,", "below the mud,", "a listening"],
    ]
    private static let dawnPoems: [[String]] = [
        ["first light forgives", "the night", "its shadows"],
        ["dew on the wheel —", "each letter", "washed new"],
        ["the crane unfolds;", "the morning", "holds its breath"],
    ]
}
