import SwiftUI
import LevelGen

struct GeneratedImageView<Fallback: View>: View {
    let request: VisualRequest
    var maxPixel: Int = 512
    @ViewBuilder let fallback: () -> Fallback

    @EnvironmentObject private var visuals: VisualProviderBox
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
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
