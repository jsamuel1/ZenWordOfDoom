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

    /// Doom-timer score multiplier. The clock is a bonus window, not a
    /// forfeit: words found with more than 2/3 of the limit remaining score
    /// 4x, more than 1/3 remaining 3x, any time still on the clock 2x, and
    /// after expiry plain 1x — points never stop, only the bonus does.
    /// Thresholds are fractions of the limit so they hold for any timer
    /// length (e.g. the longer Reduced Doom limit).
    public static func doomMultiplier(timeRemaining: TimeInterval, timeLimit: TimeInterval) -> Int {
        guard timeLimit > 0, timeRemaining > 0 else { return 1 }
        let fraction = timeRemaining / timeLimit
        if fraction > 2.0 / 3.0 { return 4 }
        if fraction > 1.0 / 3.0 { return 3 }
        return 2
    }
}
