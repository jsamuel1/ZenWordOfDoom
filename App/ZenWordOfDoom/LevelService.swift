import Foundation
import GameCore
import LevelGen

/// Resolves level ids to playable `Level`s and exposes the procedural play
/// order. Generation is async (a Foundation Models word provider slots in
/// later); today it is deterministic and effectively instant.
@MainActor
final class LevelService: ObservableObject {
    private let library = ProceduralLevelLibrary.standard
    private let generator: ProceduralGenerator

    init(wordProvider: any ThemedWordProvider = DeterministicWordProvider()) {
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
}
