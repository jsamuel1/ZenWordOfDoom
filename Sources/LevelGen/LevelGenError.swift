import Foundation

/// Honest failure modes of the level-generation pipeline. Previously these
/// were `precondition`s — uncatchable crashes. Every seed in the shipped
/// libraries is swept by `SolvabilitySweepTests` and known-good, so these
/// should never fire in practice; they exist so a genuinely bad seed (or a
/// future regression) degrades to a retry screen instead of a hard crash.
public enum LevelGenError: Error, Equatable {
    /// No word in the theme lexicon has the wheel length required by the
    /// band, so no anchor word (and thus no wheel) can be picked.
    case noAnchorWord(theme: Theme, length: Int)

    /// The word pool produced no placeable grid, so the crossword layout
    /// came back empty for the given seed.
    case emptyGrid(seedID: String, poolSize: Int)
}
