import Foundation
import Combine
import GameCore
import WordEngine

/// Bridges the pure `GameEngine` to SwiftUI. Tap input is wired here; swipe and
/// voice (docs/SPEC.md §5) plug into the same `submit` path in later milestones.
@MainActor
final class GameViewModel: ObservableObject {
    private let engine: GameEngine
    private let builder = WordBuilder()

    @Published private(set) var selection: [Int] = []
    @Published private(set) var filledCells: [GridCoord: Character] = [:]
    @Published private(set) var solvedSlotIDs: Set<Int> = []
    @Published private(set) var bonusWords: [String] = []
    @Published private(set) var stir: Double = 0
    @Published private(set) var isComplete = false
    @Published private(set) var lastMessage: String = "Tap letters to build a word"

    init(level: Level = SampleLevel.make(),
         validator: WordValidating = SampleWords.dictionary) {
        self.engine = GameEngine(level: level, validator: validator)
        sync()
    }

    var level: Level { engine.level }
    var currentWord: String { builder.currentWord(on: engine.level.wheel) }

    func tap(tileID: Int) {
        if selection.isEmpty {
            builder.apply(.begin(tileID: tileID))
        } else {
            builder.apply(.extend(tileID: tileID))
        }
        selection = builder.selection
    }

    func clear() {
        builder.apply(.cancel)
        selection = builder.selection
        lastMessage = "Cleared"
    }

    func submit() {
        guard let ids = builder.apply(.submit) else { return }
        let word = String(ids.compactMap { id in
            engine.level.wheel.tiles.first { $0.id == id }?.letter
        })
        selection = []
        switch engine.submit(word) {
        case .filledSlots:
            lastMessage = "✓ \(word)"
        case .bonusWord:
            lastMessage = "Bonus: \(word)"
        case .invalid(let reason):
            lastMessage = message(for: reason, word: word)
        }
        sync()
    }

    private func message(for reason: InvalidReason, word: String) -> String {
        switch reason {
        case .tooShort:        return "Too short"
        case .notBuildable:    return "Not on the wheel"
        case .notInDictionary: return "“\(word)” isn’t a word"
        case .alreadyFound:    return "Already found"
        }
    }

    private func sync() {
        filledCells = engine.filledCells
        solvedSlotIDs = engine.solvedSlotIDs
        bonusWords = engine.bonusWords
        stir = engine.stir
        isComplete = engine.isComplete
    }
}
