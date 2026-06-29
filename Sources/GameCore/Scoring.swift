import Foundation

/// Pure scoring rules. Longer words score more; a pangram (a word using the full
/// wheel) earns a flat bonus on top of its length score.
public enum Scoring {
    /// Score for a word that fills one or more grid slots.
    /// Quadratic-ish growth so longer answers feel rewarding, plus a pangram bonus.
    public static func wordScore(length: Int, isPangram: Bool) -> Int {
        guard length > 0 else { return 0 }
        // Base: 10 per letter, plus a small length-squared kicker.
        let base = length * 10 + (length * length)
        let pangram = isPangram ? 50 : 0
        return base + pangram
    }

    /// Score for a valid word that is not part of the grid (a bonus word).
    /// Smaller than an equivalent grid word so the grid stays the main path.
    public static func bonusScore(length: Int) -> Int {
        guard length > 0 else { return 0 }
        return length * 5
    }
}
