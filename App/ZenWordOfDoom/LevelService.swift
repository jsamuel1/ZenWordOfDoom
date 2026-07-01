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

    init(wordProvider: any ThemedWordProvider = FoundationModelsWordProvider()) {
        self.generator = ProceduralGenerator(wordProvider: wordProvider,
                                             pools: .zenDoom)
    }

    /// Generate (or in future, fetch from cache) the level for an id. Falls back
    /// to a sample level if the id is unknown or generation fails, so the player
    /// is never stranded on a blank screen.
    func level(id: String) async -> Level {
        guard let seed = library.seed(forID: id) else { return SampleLevel.make() }
        do { return try await generator.level(for: seed) }
        catch { return SampleLevel.make() }
    }

    func id(atOrder order: Int) -> String { library.id(atOrder: order) }
    func order(forID id: String) -> Int? { library.order(forID: id) }
    func nextID(after id: String) -> String? { library.nextID(after: id) }
    func ids(through order: Int) -> [String] { library.ids(through: order) }
    func wheelSize(forID id: String) -> Int { library.wheelSize(forID: id) }

    /// The theme for an id (for themed loaders / cut scenes), defaulting to zen.
    func theme(forID id: String) -> Theme {
        library.seed(forID: id)?.theme ?? .zen
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
