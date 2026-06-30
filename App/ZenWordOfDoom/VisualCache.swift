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

    func key(for request: VisualRequest, style: String) -> String {
        "\(request.id)-\(request.kind.rawValue)-\(style)-v\(VisualPrompts.promptVersion)"
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
