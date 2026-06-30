import CoreGraphics
import LevelGen

enum VisualKind: String { case scene, creature }

struct VisualRequest: Hashable {
    let id: String
    let theme: Theme
    let kind: VisualKind
}

/// Produces a themed image for a request, on-device, or nil if unavailable.
protocol SceneVisualProvider: Sendable {
    func image(for request: VisualRequest, maxPixel: Int) async -> CGImage?
}

/// Default provider until Image Playground is wired in; always nil so callers
/// fall back to procedural rendering.
struct UnavailableVisualProvider: SceneVisualProvider {
    func image(for request: VisualRequest, maxPixel: Int) async -> CGImage? { nil }
}
