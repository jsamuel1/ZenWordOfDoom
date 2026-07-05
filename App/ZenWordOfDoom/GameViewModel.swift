import Foundation
import Combine
import GameCore

/// Drives a single playable level. Bridges the pure `GameEngine` to SwiftUI and
/// wires scoring, hints, the doom timer, voice submission, and completion
/// (which records the clear into `GameStore` and reveals the creature).
@MainActor
final class GameViewModel: ObservableObject {
    private let engine: GameEngine
    private let builder = WordBuilder()
    private let settings: AppSettings
    private let store: GameStore
    private let soundEngine: any SoundEngine
    /// Musical mood for this level (its theme), fed to the sound engine with stir.
    private let mood: MusicMood
    /// Posts VoiceOver announcements for meaningful `lastMessage` changes and
    /// doom-timer urgency. Swappable in tests via `SpyAnnouncer`.
    private let announcer: any AccessibilityAnnouncing

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
    /// Set once on completion to drive the level-clear celebration overlay.
    @Published private(set) var clearSummary: ClearSummary?
    /// True when the last hint attempt failed for lack of serenity — the status
    /// message becomes a tappable path to the top-up sheet (the only in-play
    /// store surface; never a popup).
    @Published private(set) var wantsSerenityOffer = false
    /// Doom timer ran out: words still score, but the bonus multiplier is gone
    /// (and serenity payouts are forfeit — see `GameStore`'s voided handling).
    @Published private(set) var doomExpired = false
    /// Current doom bonus multiplier (4x/3x/2x by time remaining, 1x after
    /// expiry and in zen mode). Mirrors the engine for the timer readout.
    @Published private(set) var scoreMultiplier = 1
    /// Drives the full-screen "continue without points" overlay.
    @Published private(set) var showDoomOverlay = false

    /// True once the player has used at least one hint reveal this level.
    private var usedHint = false
    /// How many hint cells have been revealed (also seeds the deterministic RNG).
    private var revealCount: Int = 0
    /// Bonus words that count toward the saved progress record.
    private var bonusWordCount: Int = 0

    private var timer: Timer?
    private var deadline: Date?
    /// Doom-timer urgency thresholds (seconds) already announced this level,
    /// so each is spoken at most once as the countdown crosses it.
    private var announcedThresholds: Set<Int> = []
    private static let urgencyThresholds = [30, 15, 5]

    /// Re-roll counter feeding the wheel shuffle so each press changes the order.
    private var shuffleSalt: UInt64 = 0

    init(level: Level,
         validator: WordValidating,
         settings: AppSettings,
         store: GameStore,
         soundEngine: any SoundEngine = NullSoundEngine(),
         mood: MusicMood = .zen,
         announcer: any AccessibilityAnnouncing = SystemAnnouncer()) {
        self.settings = settings
        self.store = store
        self.soundEngine = soundEngine
        self.mood = mood
        self.announcer = announcer
        let mode: GameMode = settings.doomMode
            ? .doom(timeLimit: settings.reducedDoom ? 360 : 240)
            : .zen
        self.engine = GameEngine(level: level, validator: validator, mode: mode)
        // Words found before the countdown view appears still deserve the top
        // tier — the clock hasn't started, so the full limit remains.
        if case .doom(let limit) = mode {
            engine.setScoreMultiplier(Scoring.doomMultiplier(timeRemaining: limit, timeLimit: limit))
            scoreMultiplier = engine.scoreMultiplier
        }
        // Casual assist: pre-reveal each slot's first letter when enabled.
        if settings.firstLetterHints {
            engine.revealFirstLetters()
        }
        sync()
        updateAudioMood()
        displayOrder = level.wheel.displayOrder(seed: Self.wheelSeed(for: level.id))
    }

    /// Whether the hint button has anything to do. Hints reveal a crossword
    /// slot's letter; `.pangramHunt` levels (boss capstones and Word of the
    /// Day) have no slots, so the button would be a dead affordance.
    var hintsAvailable: Bool {
        switch engine.level.format {
        case .crossword: return true
        case .pangramHunt: return false
        }
    }

    /// Progress toward finishing the level, for the found-words tray.
    /// Crossword: grid slots solved out of the grid's total. Boss: there's no
    /// fixed word list to count against (the target is just the *minimum* to
    /// clear, and every valid word keeps counting after that), so it's just
    /// the running total found.
    var progressLabel: String {
        switch engine.level.format {
        case .crossword:
            return "\(solvedSlotIDs.count) / \(engine.level.slots.count) words"
        case .pangramHunt:
            let pangramMark = engine.pangramCount > 0 ? " ✦" : ""
            let word = bonusWords.count == 1 ? "word" : "words"
            return "\(bonusWords.count) \(word) found\(pangramMark)"
        }
    }

    /// Stable FNV-1a seed from the level id so the initial wheel order is
    /// shuffled (not canonical) yet reproducible across launches.
    private static func wheelSeed(for id: String) -> UInt64 {
        FNV1a.hash(id)
    }

    // MARK: Derived

    var level: Level { engine.level }
    var currentWord: String { builder.currentWord(on: engine.level.wheel) }

    /// Serenity currency available to spend on hints.
    var serenity: Int { store.state.serenity }

    /// Cost of one hint reveal in serenity.
    var hintCost: Int { Economy.hintCost }

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
            announcer.announce(lastMessage)
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
            soundEngine.play(.wordLand)
            store.recordWord(word, levelID: engine.level.id,
                             isBonus: false, isPangram: engine.isPangram(word), voided: doomExpired)
            lastMessage = "Found \(word)"
        case .bonusWord:
            soundEngine.play(.bonus)
            bonusWordCount += 1
            store.recordWord(word, levelID: engine.level.id,
                             isBonus: true, isPangram: engine.isPangram(word), voided: doomExpired)
            lastMessage = "Bonus: \(word)"
        case .invalid(let reason):
            soundEngine.play(.invalid)
            lastMessage = message(for: reason, word: word)
        }
        announcer.announce(lastMessage)
        sync()
        updateAudioMood()
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
            lastMessage = "Not enough serenity — tap for more"
            announcer.announce(lastMessage)
            wantsSerenityOffer = true
            return
        }
        wantsSerenityOffer = false
        let seed = seedForHint()
        var gen = SeededRandom(seed: seed)
        guard let (_, letter) = engine.revealHintCell(using: &gen) else {
            // Refund: nothing was revealed.
            store.addSerenity(hintCost)
            lastMessage = "Nothing left to reveal"
            announcer.announce(lastMessage)
            return
        }
        usedHint = true
        revealCount += 1
        soundEngine.play(.hintReveal)
        lastMessage = "Revealed \(letter)"
        announcer.announce(lastMessage)
        sync()
        updateAudioMood()
    }

    private func seedForHint() -> UInt64 {
        FNV1a.hash(engine.level.id) &+ UInt64(revealCount) &* 0x9E3779B97F4A7C15
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

    /// Internal (not private) so tests can drive it deterministically after
    /// setting a short deadline via `debugSetDeadline(_:)`, rather than
    /// waiting on the real repeating `Timer`.
    func tickTimer() {
        guard let deadline else { return }
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            timeRemaining = 0
            stopTimer()
            if !engine.isComplete { handleDoomExpiry() }
        } else {
            timeRemaining = remaining
            refreshMultiplier(remaining: remaining)
            announceUrgencyIfNeeded(remaining: remaining)
        }
    }

    /// Keep the engine's doom bonus tier in step with the countdown.
    private func refreshMultiplier(remaining: TimeInterval) {
        guard case .doom(let limit) = engine.mode else { return }
        engine.setScoreMultiplier(Scoring.doomMultiplier(timeRemaining: remaining, timeLimit: limit))
        if scoreMultiplier != engine.scoreMultiplier {
            scoreMultiplier = engine.scoreMultiplier
            announcer.announce("Scoring \(scoreMultiplier) times points")
        }
    }

    /// Announces each doom-timer urgency threshold (30s/15s/5s) at most once,
    /// paired with a haptic tap, as the countdown crosses it.
    private func announceUrgencyIfNeeded(remaining: TimeInterval) {
        for threshold in Self.urgencyThresholds {
            guard remaining <= Double(threshold), !announcedThresholds.contains(threshold) else { continue }
            announcedThresholds.insert(threshold)
            announcer.announce("\(threshold) seconds remaining")
            Haptics.reveal()
        }
    }

    /// Test seam: set the countdown deadline directly so tests can drive
    /// `tickTimer()` without waiting for the real 0.1s-interval `Timer`.
    func debugSetDeadline(_ date: Date) {
        deadline = date
    }

    /// The doom timer ran out: drop the bonus multiplier to 1x (points keep
    /// flowing at base value) and raise the overlay.
    func handleDoomExpiry() {
        guard isDoom, !doomExpired, !engine.isComplete else { return }
        engine.setScoreMultiplier(1)
        scoreMultiplier = engine.scoreMultiplier
        doomExpired = true
        showDoomOverlay = true
        lastMessage = "The doom has claimed this hour"
        announcer.announce(lastMessage)
        sync()
        updateAudioMood()
    }

    /// Dismiss the expiry overlay and keep playing at base points, unbowed.
    func continueWithoutPoints() {
        showDoomOverlay = false
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
        soundEngine.play(.levelClear)
        creatureRevealed = true
        let alreadyRevealed = store.state.bestiary[engine.level.creatureID] != nil
        let serenityBefore = store.state.serenity
        store.recordClear(
            level: engine.level,
            score: engine.score,
            bonusWords: bonusWordCount,
            usedHint: usedHint,
            creatureRevealed: !alreadyRevealed,
            voided: doomExpired
        )
        // A creature is "new" only if it wasn't already in the bestiary and the
        // clear actually catalogued it (Doom levels only — the store enforces this).
        let newCreature = (!alreadyRevealed && store.state.bestiary[engine.level.creatureID] != nil)
            ? engine.level.creatureID : nil
        clearSummary = ClearSummary(
            score: engine.score,
            serenityEarned: store.state.serenity - serenityBefore,
            newCreatureID: newCreature
        )
        isComplete = true
        lastMessage = "The garden settles\u{2026}"
        announcer.announce("Level cleared")
    }

    // MARK: Sync

    private func sync() {
        filledCells = engine.filledCells
        solvedSlotIDs = engine.solvedSlotIDs
        bonusWords = engine.bonusWords
        stir = engine.stir
        score = engine.score
    }

    /// Push the current stir into the generative bed (reactive doom bus).
    private func updateAudioMood() {
        soundEngine.setMood(mood, stir: engine.stir)
    }
}
