import Foundation
import GameCore

public enum WheelPicker {
    /// Wheel length (max word length) for a band.
    public static func wheelLength(for band: DifficultyBand) -> Int {
        switch band {
        case .easy: return 5
        case .medium: return 6
        case .hard: return 7
        case .expert: return 8
        case .master: return 9
        }
    }

    /// Deterministically pick a themed base word of the band's length from the
    /// theme lexicon; its letters form the wheel.
    public static func wheel(theme: Theme, band: DifficultyBand, index: Int) -> Wheel {
        let n = wheelLength(for: band)
        let candidates = ThemeLexicon.shared.words(for: theme)
            .filter { $0.count == n }
            .sorted()
        precondition(!candidates.isEmpty, "no length-\(n) \(theme) anchor word")
        var rng = SeededRandom(seed: seed(theme: theme, band: band, index: index))
        let pick = candidates[Int(rng.next() % UInt64(candidates.count))]
        return Wheel(letters: pick)
    }

    /// Stable FNV-1a seed for a (theme, band, index) triple.
    static func seed(theme: Theme, band: DifficultyBand, index: Int) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for s in [theme.rawValue, band.rawValue, "\(index)"] {
            for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        }
        return h
    }
}
