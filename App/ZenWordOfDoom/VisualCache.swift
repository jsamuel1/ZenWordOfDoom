import UIKit
import LevelGen

/// Disk cache for generated visuals under Caches/visuals/. Disposable.
struct VisualCache {
    static let shared = VisualCache()
    private let dir: URL

    init() {
        let base = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        dir = base.appendingPathComponent("visuals", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Stable across sessions/devices: keyed by id, kind, and prompt version
    /// only — not the runtime style — so a previously generated image always
    /// round-trips. Bump `VisualPrompts.promptVersion` to invalidate.
    func key(for request: VisualRequest) -> String {
        "\(request.id)-\(request.kind.rawValue)-v\(VisualPrompts.promptVersion)"
    }
    private func url(_ key: String) -> URL { dir.appendingPathComponent(key + ".png") }

    func image(forKey key: String) -> CGImage? {
        guard let data = try? Data(contentsOf: url(key)), let img = UIImage(data: data) else { return nil }
        return img.cgImage
    }
    func store(_ cgImage: CGImage, forKey key: String) {
        let img = UIImage(cgImage: cgImage)
        guard let data = img.pngData() else { return }
        try? data.write(to: url(key), options: [.atomic])
    }
}
