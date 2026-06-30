import ImagePlayground
import CoreGraphics
import UIKit
import LevelGen

/// On-device visual provider backed by the programmatic Image Playground
/// `ImageCreator` API. Falls back to nil (procedural rendering) whenever the
/// creator is unavailable on this device/simulator or generation fails.
actor ImagePlaygroundVisualProvider: SceneVisualProvider {
    private var creator: ImageCreator?
    private var unavailable = false

    private func makeCreator() async -> ImageCreator? {
        if let creator { return creator }
        if unavailable { return nil }
        do {
            let c = try await ImageCreator()
            creator = c
            return c
        } catch {
            unavailable = true
            return nil
        }
    }

    /// Pick a stylized illustration style, falling back to the first available.
    private func style(for creator: ImageCreator) -> ImagePlaygroundStyle? {
        creator.availableStyles.first { $0 == .illustration }
            ?? creator.availableStyles.first { "\($0.id)".lowercased().contains("illustration") }
            ?? creator.availableStyles.first
    }

    func image(for request: VisualRequest, maxPixel: Int) async -> CGImage? {
        guard let creator = await makeCreator() else { return nil }
        guard let style = style(for: creator) else { return nil }

        let cacheKey = VisualCache.shared.key(for: request, style: "\(style.id)")
        if let cached = VisualCache.shared.image(forKey: cacheKey) { return cached }

        let prompt = request.kind == .scene
            ? VisualPrompts.prompt(forSceneID: request.id, theme: request.theme)
            : VisualPrompts.prompt(forCreatureID: request.id, theme: request.theme)

        do {
            for try await created in creator.images(for: [.text(prompt)], style: style, limit: 1) {
                let scaled = created.cgImage.downscaled(maxPixel: maxPixel) ?? created.cgImage
                VisualCache.shared.store(scaled, forKey: cacheKey)
                return scaled
            }
        } catch {
            return nil
        }
        return nil
    }
}

private extension CGImage {
    /// Downscale so the longest side is <= maxPixel, preserving aspect.
    func downscaled(maxPixel: Int) -> CGImage? {
        let longest = max(width, height)
        guard longest > maxPixel, longest > 0 else { return self }
        let scale = CGFloat(maxPixel) / CGFloat(longest)
        let w = Int((CGFloat(width) * scale).rounded())
        let h = Int((CGFloat(height) * scale).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return self }
        ctx.interpolationQuality = .high
        ctx.draw(self, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
