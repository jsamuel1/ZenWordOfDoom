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

    /// Scene-coupled wheel: prefer a word from the scene's lexicon of the band's
    /// length so the letters (and thus the words) relate to the revealed scene.
    /// Falls back to the theme anchor when the scene has no word of that length,
    /// guaranteeing a non-empty, buildable wheel for every seed.
    public static func wheel(sceneID: String, theme: Theme, band: DifficultyBand, index: Int) -> Wheel {
        let n = wheelLength(for: band)
        let candidates = SceneLexicon.shared.words(for: sceneID)
            .filter { $0.count == n }
            .sorted()
        guard !candidates.isEmpty else { return wheel(theme: theme, band: band, index: index) }
        var rng = SeededRandom(seed: seed(theme: theme, band: band, index: index))
        return Wheel(letters: candidates[Int(rng.next() % UInt64(candidates.count))])
    }

    /// Stable FNV-1a seed for a (theme, band, index) triple.
    static func seed(theme: Theme, band: DifficultyBand, index: Int) -> UInt64 {
        FNV1a.hash(theme.rawValue + band.rawValue + "\(index)")
    }
}
