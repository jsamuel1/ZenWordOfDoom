import Foundation
import GameCore

/// Loads and serves the bundled level / cut-scene / pack content from
/// `Bundle.module`. All JSON is decoded once, lazily, and cached.
public enum LevelLibrary {

    // MARK: - Cached decoded content

    private static let levelData: [LevelData] = {
        loadArray("levels", as: LevelData.self)
    }()

    private static let cutScenes: [CutSceneData] = {
        loadArray("cutscenes", as: CutSceneData.self)
    }()

    private static let packData: [PackData] = {
        loadArray("packs", as: PackData.self)
    }()

    // MARK: - Levels

    /// All levels, in the order packs declare them (the canonical play order).
    public static func allLevels() -> [Level] {
        orderedLevelIDs().compactMap { level(id: $0) }
    }

    public static func level(id: String) -> Level? {
        levelData.first { $0.id == id }?.toLevel()
    }

    /// The play order: every level referenced by every pack, in pack order.
    /// Any level not referenced by a pack is appended in file order.
    public static func orderedLevelIDs() -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        for pack in packData {
            for id in pack.levelIDs where seen.insert(id).inserted {
                ordered.append(id)
            }
        }
        for ld in levelData where seen.insert(ld.id).inserted {
            ordered.append(ld.id)
        }
        return ordered
    }

    /// The level that follows `id` in play order, or `nil` if it is the last.
    public static func nextLevelID(after id: String) -> String? {
        let order = orderedLevelIDs()
        guard let idx = order.firstIndex(of: id), idx + 1 < order.count else {
            return nil
        }
        return order[idx + 1]
    }

    // MARK: - Packs

    public static func packs() -> [PackData] { packData }

    // MARK: - Cut scenes

    /// The breath shown after clearing `levelID` (before the next level). Keyed
    /// by cut-scene `id` matching the just-cleared level's id.
    public static func cutScene(afterLevelID levelID: String) -> CutSceneData? {
        cutScenes.first { $0.id == levelID }
    }

    // MARK: - Decoding helpers

    /// Decode a `[LevelData]` from arbitrary JSON data (used by tests).
    public static func decodeLevels(from data: Data) throws -> [LevelData] {
        try JSONDecoder().decode([LevelData].self, from: data)
    }

    private static func loadArray<T: Decodable>(_ name: String, as type: T.Type) -> [T] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            return []
        }
    }
}
