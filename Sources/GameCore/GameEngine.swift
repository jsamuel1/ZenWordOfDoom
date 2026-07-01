import Foundation

/// Supplied by WordEngine. Kept here so GameCore stays UI- and data-free.
public protocol WordValidating: Sendable {
    func isValidWord(_ word: String) -> Bool
}

public enum InvalidReason: Equatable, Sendable {
    case tooShort
    case notBuildable
    case notInDictionary
    case alreadyFound
}

public enum SubmissionResult: Equatable, Sendable {
    case filledSlots([Int])     // matched grid slot ids
    case bonusWord(String)      // valid, not in grid
    case invalid(InvalidReason)
}

/// Owns mutable level state: which cells are filled and which words are found.
public final class GameEngine {
    public let level: Level
    private let validator: WordValidating

    /// Selected play mode. Defaults to `.zen` for the legacy initializer.
    public let mode: GameMode

    public private(set) var filledCells: [GridCoord: Character] = [:]
    public private(set) var solvedSlotIDs: Set<Int> = []
    public private(set) var foundWords: Set<String> = []
    public private(set) var bonusWords: [String] = []

    /// Accumulated score for this level (driven by `Scoring`).
    public private(set) var score: Int = 0

    /// Number of pangrams found this level.
    public private(set) var pangramCount: Int = 0

    /// 0 = calm, 1 = creature fully revealed. Driven by progress.
    public private(set) var stir: Double = 0

    public static let minWordLength = 3

    public init(level: Level, validator: WordValidating) {
        self.level = level
        self.validator = validator
        self.mode = .zen
    }

    public init(level: Level, validator: WordValidating, mode: GameMode) {
        self.level = level
        self.validator = validator
        self.mode = mode
    }

    public var isComplete: Bool {
        switch level.format {
        case .crossword:
            return solvedSlotIDs.count == level.slots.count
        case .pangramHunt(let target):
            // Boss: find the pangram plus a word-count target. Boss levels have
            // no grid, so every valid word lands in `foundWords` via the bonus
            // path in `submit`.
            return pangramCount >= 1 && foundWords.count >= target
        }
    }

    public var progress: Double {
        switch level.format {
        case .crossword:
            return level.slots.isEmpty ? 1 : Double(solvedSlotIDs.count) / Double(level.slots.count)
        case .pangramHunt(let target):
            guard target > 0 else { return 1 }
            return min(1, Double(foundWords.count) / Double(target))
        }
    }

    /// A word is a pangram when it spans the whole wheel and is buildable from it.
    public func isPangram(_ word: String) -> Bool {
        let w = word.uppercased()
        return w.count == level.wheel.size && level.wheel.multiset.canBuild(w)
    }

    /// Submit a word string (already resolved from tiles or speech).
    @discardableResult
    public func submit(_ rawWord: String) -> SubmissionResult {
        let word = rawWord.uppercased()

        guard word.count >= Self.minWordLength, word.count <= level.wheel.size else {
            return .invalid(.tooShort)
        }
        guard level.wheel.multiset.canBuild(word) else {
            return .invalid(.notBuildable)
        }
        if foundWords.contains(word) {
            return .invalid(.alreadyFound)
        }

        // A word matching an unsolved grid answer is authoritative: the level
        // generator already guaranteed it is a real, buildable word, so it fills
        // the slot WITHOUT consulting the runtime dictionary — whose word list
        // (iOS's UITextChecker) can differ from the corpus the level was built
        // from, which would otherwise make some answers impossible to enter. The
        // dictionary only gates bonus words (anything not in the grid).
        let matches = level.slots.filter { $0.answer == word && !solvedSlotIDs.contains($0.id) }

        if matches.isEmpty {
            guard validator.isValidWord(word) else {
                return .invalid(.notInDictionary)
            }
            foundWords.insert(word)
            let pangram = isPangram(word)
            if pangram { pangramCount += 1 }
            bonusWords.append(word)
            switch level.format {
            case .crossword:
                // Bonus words stay smaller than grid words so the grid is the
                // main path.
                score += Scoring.bonusScore(length: word.count)
            case .pangramHunt:
                // In a boss every collected word is the main path; the pangram
                // earns its full bonus.
                score += Scoring.wordScore(length: word.count, isPangram: pangram)
            }
            bumpStir(by: 0.02)
            // Boss levels complete here (no slots), so snap to the full reveal.
            if isComplete { stir = 1 }
            return .bonusWord(word)
        }

        foundWords.insert(word)
        let pangram = isPangram(word)
        if pangram { pangramCount += 1 }

        for slot in matches {
            solvedSlotIDs.insert(slot.id)
            for (offset, coord) in slot.cells.enumerated() {
                let ch = Array(slot.answer)[offset]
                filledCells[coord] = ch
            }
        }
        score += Scoring.wordScore(length: word.count, isPangram: pangram)
        bumpStir(by: 0.08 * Double(matches.count))
        if isComplete { stir = 1 }
        return .filledSlots(matches.map(\.id))
    }

    /// Reveal one as-yet-unfilled cell belonging to an unsolved slot, choosing
    /// deterministically from the provided generator. Fills it in `filledCells`
    /// and returns the coord/letter, or `nil` if there is nothing left to reveal.
    public func revealHintCell(using gen: inout some RandomNumberGenerator) -> (GridCoord, Character)? {
        // Gather candidate (coord, letter) pairs from unsolved slots whose cell
        // is not already filled. De-duplicate by coord (shared cells appear once).
        var candidates: [GridCoord: Character] = [:]
        for slot in level.slots where !solvedSlotIDs.contains(slot.id) {
            let letters = Array(slot.answer)
            for (offset, coord) in slot.cells.enumerated() where filledCells[coord] == nil {
                candidates[coord] = letters[offset]
            }
        }
        guard !candidates.isEmpty else { return nil }

        // Stable ordering so the random pick is reproducible for a given seed.
        let ordered = candidates.keys.sorted { a, b in
            a.row != b.row ? a.row < b.row : a.col < b.col
        }
        let idx = Int(gen.next() % UInt64(ordered.count))
        let coord = ordered[idx]
        let letter = candidates[coord]!
        filledCells[coord] = letter
        bumpStir(by: 0.01)
        return (coord, letter)
    }

    private func bumpStir(by amount: Double) {
        stir = min(1, stir + amount)
    }
}
