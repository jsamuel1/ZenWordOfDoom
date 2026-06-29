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

    public private(set) var filledCells: [GridCoord: Character] = [:]
    public private(set) var solvedSlotIDs: Set<Int> = []
    public private(set) var foundWords: Set<String> = []
    public private(set) var bonusWords: [String] = []

    /// 0 = calm, 1 = creature fully revealed. Driven by progress.
    public private(set) var stir: Double = 0

    public static let minWordLength = 3

    public init(level: Level, validator: WordValidating) {
        self.level = level
        self.validator = validator
    }

    public var isComplete: Bool { solvedSlotIDs.count == level.slots.count }

    public var progress: Double {
        level.slots.isEmpty ? 1 : Double(solvedSlotIDs.count) / Double(level.slots.count)
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
        guard validator.isValidWord(word) else {
            return .invalid(.notInDictionary)
        }

        foundWords.insert(word)

        // Fill any unsolved grid slots whose answer matches.
        let matches = level.slots.filter { $0.answer == word && !solvedSlotIDs.contains($0.id) }
        if matches.isEmpty {
            bonusWords.append(word)
            bumpStir(by: 0.02)
            return .bonusWord(word)
        }

        for slot in matches {
            solvedSlotIDs.insert(slot.id)
            for (offset, coord) in slot.cells.enumerated() {
                let ch = Array(slot.answer)[offset]
                filledCells[coord] = ch
            }
        }
        bumpStir(by: 0.08 * Double(matches.count))
        if isComplete { stir = 1 }
        return .filledSlots(matches.map(\.id))
    }

    private func bumpStir(by amount: Double) {
        stir = min(1, stir + amount)
    }
}
