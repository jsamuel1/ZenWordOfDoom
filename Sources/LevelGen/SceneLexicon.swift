import Foundation

/// Words associated with each bundled scene, used to couple a level's words to
/// the scene being revealed. Authored once (curated, reviewed) and bundled as
/// `Resources/scene-lexicon.json`; slugs match `ThemePools.zenDoom` scene ids.
public struct SceneLexicon: Sendable {
    public static let shared = SceneLexicon()

    private let bySlug: [String: [String]]

    public init() { self.bySlug = Self.load() }

    /// Curated words for a scene, uppercased and de-duplicated. Empty for an
    /// unknown slug.
    public func words(for sceneID: String) -> [String] { bySlug[sceneID] ?? [] }

    private static func load() -> [String: [String]] {
        guard let url = Bundle.module.url(forResource: "scene-lexicon", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return raw.mapValues { list in
            let cleaned = list
                .map { String($0.uppercased().filter(\.isLetter)) }
                .filter { !$0.isEmpty }
            return Array(Set(cleaned)).sorted()
        }
    }
}
