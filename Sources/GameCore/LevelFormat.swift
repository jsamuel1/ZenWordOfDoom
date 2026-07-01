import Foundation

/// How a level is won.
///
/// - `crossword`: fill every slot in the interlocking grid (the default format).
/// - `pangramHunt`: a boss capstone with no grid — find the pangram (a word
///   using all wheel letters) *and* at least `target` valid words total.
public enum LevelFormat: Equatable, Sendable {
    case crossword
    case pangramHunt(target: Int)
}
