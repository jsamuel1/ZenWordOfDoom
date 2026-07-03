import Foundation
import GameCore
import LevelGen

/// Resolves level ids to playable `Level`s and exposes the procedural play
/// order. Generation is async: the default word provider uses on-device
/// Foundation Models when available, falling back to the deterministic corpus
/// (and to that floor on every device without Apple Intelligence).
@MainActor
final class LevelService: ObservableObject {
    private let library = ProceduralLevelLibrary.standard
    private let generator: ProceduralGenerator
    private var cache: [String: Level] = [:]

    init(wordProvider: any ThemedWordProvider = FoundationModelsWordProvider()) {
        self.generator = ProceduralGenerator(wordProvider: wordProvider,
                                             pools: .zenDoom)
    }

    /// Resolve a level id, memoized. Returns nil when generation genuinely
    /// fails — the container shows a retry state; we no longer strand the
    /// player in a mislabeled SampleLevel.
    func level(id: String) async -> Level? {
        if let hit = cache[id] { return hit }
        if DailyPuzzle.isDailyID(id) {
            guard let seed = DailyPuzzle.seed(forID: id),
                  let wordOfTheDay = DailyPuzzle.wordOfTheDay(forID: id) else { return nil }
            let raw = generator.dailyLevel(for: seed, word: wordOfTheDay.word)
            // Re-key by date so progress/streak records land on the day.
            let level = Level(id: id, wheel: raw.wheel, slots: raw.slots,
                              sceneID: raw.sceneID, creatureID: raw.creatureID,
                              format: raw.format)
            cache[id] = level
            return level
        }
        guard let seed = library.seed(forID: id) else { return nil }
        do {
            let level = try await generator.level(for: seed)
            cache[id] = level
            return level
        } catch {
            return nil
        }
    }

    func id(atOrder order: Int) -> String { library.id(atOrder: order) }
    func order(forID id: String) -> Int? { library.order(forID: id) }
    func nextID(after id: String) -> String? { library.nextID(after: id) }
    func ids(through order: Int) -> [String] { library.ids(through: order) }
    func wheelSize(forID id: String) -> Int { library.wheelSize(forID: id) }

    /// Number of levels per pack, single-sourced from the library (never
    /// hardcode this elsewhere).
    var packSize: Int { library.packSize }

    /// The theme for an id (for themed loaders / cut scenes), defaulting to zen.
    func theme(forID id: String) -> Theme {
        if DailyPuzzle.isDailyID(id) { return DailyPuzzle.seed(forID: id)?.theme ?? .zen }
        return library.seed(forID: id)?.theme ?? .zen
    }

    /// The pack a level belongs to (name/flavor/signature), or nil if unknown.
    func pack(forID id: String) -> Pack? {
        guard let order = library.order(forID: id) else { return nil }
        return PackCatalog.standard.pack(forOrder: order, packSize: library.packSize)
    }

    /// True when this level is the first of its pack (show the pack banner).
    func isPackStart(_ id: String) -> Bool {
        guard let order = library.order(forID: id) else { return false }
        return order % library.packSize == 0
    }
}
