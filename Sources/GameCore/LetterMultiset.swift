import Foundation

/// A count of available letters, used to test whether a word can be built from
/// the wheel without re-using any single tile more often than it appears.
public struct LetterMultiset: Equatable, Sendable {
    private var counts: [Character: Int]

    public init(_ letters: [Character]) {
        var c: [Character: Int] = [:]
        for raw in letters {
            let ch = Character(String(raw).uppercased())
            c[ch, default: 0] += 1
        }
        self.counts = c
    }

    public init(_ word: String) {
        self.init(Array(word))
    }

    public func count(of letter: Character) -> Int {
        counts[Character(String(letter).uppercased()), default: 0]
    }

    /// True if every letter of `word` is available with sufficient multiplicity.
    public func canBuild(_ word: String) -> Bool {
        var remaining = counts
        for raw in word.uppercased() {
            let ch = raw
            guard ch.isLetter else { continue }
            let left = remaining[ch, default: 0]
            if left == 0 { return false }
            remaining[ch] = left - 1
        }
        return true
    }
}
