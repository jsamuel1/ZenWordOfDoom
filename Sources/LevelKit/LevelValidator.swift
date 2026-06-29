import Foundation
import GameCore

/// Static validation of authored levels. Returns a (possibly empty) list of
/// human-readable problems. An empty list means the level is well-formed.
public enum LevelValidator {

    public static func problems(in level: Level, dictionary: WordValidating) -> [String] {
        var problems: [String] = []

        let wheelMultiset = level.wheel.multiset

        // 1. Every slot answer must be buildable from the wheel, in the
        //    dictionary, and at least the minimum length.
        for slot in level.slots {
            let answer = slot.answer
            if answer.count < GameEngine.minWordLength {
                problems.append("slot \(slot.id) answer \"\(answer)\" is shorter than \(GameEngine.minWordLength)")
            }
            if answer.count > level.wheel.size {
                problems.append("slot \(slot.id) answer \"\(answer)\" is longer than the wheel (\(level.wheel.size))")
            }
            if !wheelMultiset.canBuild(answer) {
                problems.append("slot \(slot.id) answer \"\(answer)\" is not buildable from the wheel")
            }
            if !dictionary.isValidWord(answer) {
                problems.append("slot \(slot.id) answer \"\(answer)\" is not in the dictionary")
            }
        }

        // 2. Wheel multiset must equal the per-letter maximum across all answers
        //    (no unused wheel letters, no letter scarcer than some answer needs).
        let required = requiredMultiset(for: level.slots)
        let allLetters = Set(letterCounts(level.wheel).keys).union(required.keys)
        for letter in allLetters {
            let have = wheelMultiset.count(of: letter)
            let need = required[letter, default: 0]
            if have != need {
                problems.append("wheel letter \(letter): wheel has \(have) but answers require a max of \(need)")
            }
        }

        // 3. Grid cells must not carry conflicting letters at shared coords.
        var cellLetters: [GridCoord: Character] = [:]
        for slot in level.slots {
            let letters = Array(slot.answer)
            for (offset, coord) in slot.cells.enumerated() {
                let ch = letters[offset]
                if let existing = cellLetters[coord], existing != ch {
                    problems.append("cell (\(coord.row),\(coord.col)) conflict: \(existing) vs \(ch)")
                } else {
                    cellLetters[coord] = ch
                }
            }
        }

        // 4. Answers must form a single connected crossword (share cells).
        if !isConnected(level.slots) {
            problems.append("slots are not all connected through shared cells")
        }

        // 5. For hard bands and above, at least one answer must use every wheel
        //    letter (a pangram).
        switch level.band {
        case .hard, .expert, .master:
            let hasPangram = level.slots.contains { slot in
                slot.answer.count == level.wheel.size && wheelMultiset.canBuild(slot.answer)
            }
            if !hasPangram {
                problems.append("band \(level.band.rawValue) requires at least one answer using all wheel letters")
            }
        case .easy, .medium:
            break
        }

        return problems
    }

    // MARK: - Helpers

    private static func letterCounts(_ wheel: Wheel) -> [Character: Int] {
        var counts: [Character: Int] = [:]
        for tile in wheel.tiles {
            counts[tile.letter, default: 0] += 1
        }
        return counts
    }

    /// Per-letter maximum multiplicity needed by any single answer.
    private static func requiredMultiset(for slots: [GridSlot]) -> [Character: Int] {
        var maxNeeded: [Character: Int] = [:]
        for slot in slots {
            var perAnswer: [Character: Int] = [:]
            for ch in slot.answer {
                perAnswer[ch, default: 0] += 1
            }
            for (ch, n) in perAnswer {
                maxNeeded[ch] = max(maxNeeded[ch, default: 0], n)
            }
        }
        return maxNeeded
    }

    /// True if every slot is reachable from the first via shared cells.
    private static func isConnected(_ slots: [GridSlot]) -> Bool {
        guard slots.count > 1 else { return true }

        let cellSets: [Set<GridCoord>] = slots.map { Set($0.cells) }
        var visited = Set<Int>()
        var stack = [0]
        visited.insert(0)

        while let current = stack.popLast() {
            for other in slots.indices where !visited.contains(other) {
                if !cellSets[current].isDisjoint(with: cellSets[other]) {
                    visited.insert(other)
                    stack.append(other)
                }
            }
        }
        return visited.count == slots.count
    }
}
