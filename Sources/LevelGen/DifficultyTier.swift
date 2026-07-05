import Foundation

/// The second axis of difficulty, orthogonal to `DifficultyBand` (wheel
/// size): how RICH the wheel's word pool is. An `easy`-tier anchor builds
/// plenty of common words (lots to find, lots of slack); a `hard`-tier
/// anchor builds barely more than the grid demands — fewer possible words,
/// same required number. Tier thresholds per length live in
/// `scripts/generate-anchor-pools.sh`.
///
/// Raw values are the `anchor-pools.json` tier keys.
public enum DifficultyTier: String, CaseIterable, Sendable {
    case easy
    case medium
    case hard
}
