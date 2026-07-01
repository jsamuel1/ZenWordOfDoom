import Foundation
import Combine
import GameCore
import WordEngine

/// Drives a single playable level. Bridges the pure `GameEngine` to SwiftUI and
/// wires scoring, hints, the doom timer, voice submission, and completion
/// (which records the clear into `GameStore` and reveals the creature).
@MainActor
final class GameViewModel: ObservableObject {
    private let engine: GameEngine
    private let builder = WordBuilder()
    private let settings: AppSettings
    private let store: GameStore

    @Published private(set) var selection: [Int] = []
    /// Tile-id order for placing tiles around the wheel. Re-rolled by `shuffle()`.
    @Published private(set) var displayOrder: [Int] = []
    @Published private(set) var filledCells: [GridCoord: Character] = [:]
    @Published private(set) var solvedSlotIDs: Set<Int> = []
    @Published private(set) var bonusWords: [String] = []
    @Published private(set) var stir: Double = 0
    @Published private(set) var isComplete = false
    @Published private(set) var score: Int = 0
    @Published private(set) var lastMessage: String = "Tap or speak letters to build a word"
    /// Present only in doom mode; counts down to zero.
    @Published private(set) var timeRemaining: TimeInterval?
    @Published private(set) var creatureRevealed: Bool = false

    /// True once the player has used at least one hint reveal this level.
    private var usedHint = false
    /// How many hint cells have been revealed (also seeds the deterministic RNG).
    private var revealCount: Int = 0
    /// Bonus words that count toward the saved progress record.
    private var bonusWordCount: Int = 0

    private var timer: Timer?
    private var deadline: Date?

    /// Re-roll counter feeding the wheel shuffle so each press changes the order.
    private var shuffleSalt: UInt64 = 0

    init(level: Level,
         validator: WordValidating,
         settings: AppSettings,
         store: GameStore) {
        self.settings = settings
        self.store = store
        let mode: GameMode = settings.doomMode
            ? .doom(timeLimit: settings.reducedDoom ? 240 : 150)
            : .zen
        self.engine = GameEngine(level: level, validator: validator, mode: mode)
        // Casual assist: pre-reveal each slot's first letter when enabled.
        if settings.firstLetterHints {
            engine.revealFirstLetters()
        }
        sync()
        displayOrder = level.wheel.displayOrder(seed: Self.wheelSeed(for: level.id))
    }

    /// Progress toward finishing the level, for the found-words tray.
    /// Crossword: grid slots solved. Boss: words found toward the target.
    var progressLabel: String {
        switch engine.level.format {
        case .crossword:
            return "\(solvedSlotIDs.count) / \(engine.level.slots.count) words"
        case .pangramHunt(let target):
            let pangramMark = engine.pangramCount > 0 ? " ✦" : ""
            return "\(bonusWords.count) / \(target) words\(pangramMark)"
        }
    }

    /// Stable FNV-1a seed from the level id so the initial wheel order is
    /// shuffled (not canonical) yet reproducible across launches.
    private static func wheelSeed(for id: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in id.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }

    // MARK: Derived

    var level: Level { engine.level }
    var currentWord: String { builder.currentWord(on: engine.level.wheel) }

    /// Serenity currency available to spend on hints.
    var serenity: Int { store.state.serenity }

    /// Cost of one hint reveal in serenity.
    var hintCost: Int { 5 }

    /// Whether doom mode (and therefore the timer) is active.
    var isDoom: Bool {
        if case .doom = engine.mode { return true }
        return false
    }

    // MARK: Tap input

    func tap(tileID: Int) {
        if selection.isEmpty {
            builder.apply(.begin(tileID: tileID))
        } else {
            builder.apply(.extend(tileID: tileID))
        }
        selection = builder.selection
    }

    // MARK: Swipe input

    func swipeBegin(tileID: Int) {
        builder.apply(.cancel)
        builder.apply(.begin(tileID: tileID))
        selection = builder.selection
    }

    func swipeExtend(tileID: Int) {
        // Backtracking: if the player drags back onto the previous tile, undo.
        if selection.count >= 2, selection[selection.count - 2] == tileID {
            builder.apply(.backtrack)
        } else if !selection.contains(tileID) {
            if selection.isEmpty {
                builder.apply(.begin(tileID: tileID))
            } else {
                builder.apply(.extend(tileID: tileID))
            }
        }
        selection = builder.selection
    }

    func swipeEnd() {
        submit()
    }

    // MARK: Editing

    func clear() {
        builder.apply(.cancel)
        selection = builder.selection
        lastMessage = "Cleared"
    }

    /// Re-randomize tile positions on the wheel. Cosmetic: never changes the
    /// letter set. Cancels any in-progress word so the trail stays consistent.
    func shuffle() {
        builder.apply(.cancel)
        selection = builder.selection
        shuffleSalt &+= 1
        displayOrder = engine.level.wheel.displayOrder(
            seed: Self.wheelSeed(for: engine.level.id), salt: shuffleSalt)
        lastMessage = "Shuffled"
    }

    // MARK: Submission

    func submit() {
        guard let ids = builder.apply(.submit) else {
            selection = builder.selection
            return
        }
        selection = []
        let word = String(ids.compactMap { id in
            engine.level.wheel.tiles.first { $0.id == id }?.letter
        })
        resolveSubmission(of: word)
    }

    /// Resolve spoken text to wheel tiles greedily, then submit the word.
    func submitSpoken(_ text: String) {
        let cleaned = text.uppercased().filter { $0.isLetter }
        guard !cleaned.isEmpty else { return }
        guard engine.level.wheel.multiset.canBuild(String(cleaned)) else {
            lastMessage = "Couldn't hear letters on the wheel"
            return
        }
        // Greedily map each spoken letter onto an unused wheel tile.
        builder.apply(.cancel)
        var usedTileIDs: Set<Int> = []
        for ch in cleaned {
            if let tile = engine.level.wheel.tiles.first(where: {
                $0.letter == ch && !usedTileIDs.contains($0.id)
            }) {
                if usedTileIDs.isEmpty {
                    builder.apply(.begin(tileID: tile.id))
                } else {
                    builder.apply(.extend(tileID: tile.id))
                }
                usedTileIDs.insert(tile.id)
            }
        }
        selection = builder.selection
        submit()
    }

    private func resolveSubmission(of word: String) {
        switch engine.submit(word) {
        case .filledSlots:
            lastMessage = "Found \(word)"
        case .bonusWord:
            bonusWordCount += 1
            lastMessage = "Bonus: \(word)"
        case .invalid(let reason):
            lastMessage = message(for: reason, word: word)
        }
        sync()
        if engine.isComplete && !isComplete {
            completeLevel()
        }
    }

    private func message(for reason: InvalidReason, word: String) -> String {
        switch reason {
        case .tooShort:        return "Too short"
        case .notBuildable:    return "Not on the wheel"
        case .notInDictionary: return "\u{201C}\(word)\u{201D} isn't a word"
        case .alreadyFound:    return "Already found"
        }
    }

    // MARK: Hints

    /// Spend serenity to reveal one not-yet-filled cell of an unsolved slot.
    /// Uses a `SeededRandom` derived from the level id and the reveal count so a
    /// given level reveals cells in a reproducible order. No-ops if the player
    /// cannot afford it or there is nothing left to reveal.
    func useHintRevealCell() {
        guard !engine.isComplete else { return }
        guard store.spendSerenity(hintCost) else {
            lastMessage = "Not enough serenity"
            return
        }
        let seed = seedForHint()
        var gen = SeededRandom(seed: seed)
        guard let (_, letter) = engine.revealHintCell(using: &gen) else {
            // Refund: nothing was revealed.
            store.addSerenity(hintCost)
            lastMessage = "Nothing left to reveal"
            return
        }
        usedHint = true
        revealCount += 1
        lastMessage = "Revealed \(letter)"
        sync()
    }

    private func seedForHint() -> UInt64 {
        let base = UInt64(bitPattern: Int64(engine.level.id.hashValue))
        return base &+ UInt64(revealCount) &* 0x9E3779B97F4A7C15
    }

    // MARK: Doom timer

    func startTimerIfDoom() {
        guard case .doom(let limit) = engine.mode else { return }
        guard timer == nil else { return }
        let end = Date().addingTimeInterval(limit)
        deadline = end
        timeRemaining = limit
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickTimer() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tickTimer() {
        guard let deadline else { return }
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            timeRemaining = 0
            stopTimer()
            if !engine.isComplete {
                lastMessage = "The doom timer ran out\u{2026}"
            }
        } else {
            timeRemaining = remaining
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Tear down timers; call from the view's `onDisappear`.
    func invalidate() {
        stopTimer()
    }

    // MARK: Completion

    private func completeLevel() {
        stopTimer()
        creatureRevealed = true
        let alreadyRevealed = store.state.bestiary[engine.level.creatureID] != nil
        store.recordClear(
            level: engine.level,
            score: engine.score,
            bonusWords: bonusWordCount,
            usedHint: usedHint,
            creatureRevealed: !alreadyRevealed
        )
        // Reward serenity for clearing; a no-hint clear earns a little extra.
        store.addSerenity(usedHint ? 10 : 15)
        isComplete = true
        lastMessage = "The garden settles\u{2026}"
    }

    // MARK: Sync

    private func sync() {
        filledCells = engine.filledCells
        solvedSlotIDs = engine.solvedSlotIDs
        bonusWords = engine.bonusWords
        stir = engine.stir
        score = engine.score
    }
}
