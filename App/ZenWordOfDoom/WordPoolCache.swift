import Foundation
import GameCore
import LevelGen

/// Disk cache of generated word pools, keyed by theme + wheel letters, so a
/// level's Foundation-Models pool is generated once and reused. Disposable.
struct WordPoolCache {
    static let shared = WordPoolCache()
    static let version = 1
    private let dir: URL

    init() {
        let base = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        dir = base.appendingPathComponent("wordpools", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func key(wheel: Wheel, theme: Theme) -> String {
        let letters = wheel.tiles.map { String($0.letter) }.sorted().joined()
        return "\(theme.rawValue)-\(letters)-v\(Self.version)"
    }
    private func url(_ key: String) -> URL { dir.appendingPathComponent(key + ".json") }

    func pool(wheel: Wheel, theme: Theme) -> [String]? {
        guard let data = try? Data(contentsOf: url(key(wheel: wheel, theme: theme))) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
    func store(_ pool: [String], wheel: Wheel, theme: Theme) {
        guard let data = try? JSONEncoder().encode(pool) else { return }
        try? data.write(to: url(key(wheel: wheel, theme: theme)), options: [.atomic])
    }
}
