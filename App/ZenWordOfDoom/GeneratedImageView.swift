import SwiftUI
import LevelGen

/// Shows, in priority order: a freshly generated on-device image (once ready),
/// else a bundled pre-rendered image for this slug (instant, works on every
/// device), else the caller's fully-procedural `fallback`. The bundled image
/// is replaced by the live one only if/when on-device generation succeeds.
struct GeneratedImageView<Fallback: View>: View {
    let request: VisualRequest
    var maxPixel: Int = 512
    var contentMode: ContentMode = .fill
    @ViewBuilder let fallback: () -> Fallback

    @EnvironmentObject private var visuals: VisualProviderBox
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if let bundledName = BundledVisuals.assetName(for: request) {
                Image(bundledName).resizable().aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                fallback()
            }
        }
        .task(id: request) {
            if let cg = await visuals.provider.image(for: request, maxPixel: maxPixel) {
                withAnimation(.easeIn(duration: 0.4)) { image = cg }
            }
        }
    }
}

/// Environment box so the provider can be swapped without touching call sites.
@MainActor
final class VisualProviderBox: ObservableObject {
    let provider: SceneVisualProvider
    init(provider: SceneVisualProvider) { self.provider = provider }
}
