import SwiftUI
import LevelGen

/// The in-level background. Shows the bundled **scene** painting as the calm base
/// and slowly surfaces the paired **creature** painting as `stir` rises (spec
/// workstream A), with a stir-driven desaturate/darken/vignette treatment. Falls
/// back to the fully procedural `RevealBackgroundView` for any slug without
/// bundled art (e.g. the hand-authored `SampleLevel`), so the screen is never
/// blank.
///
/// - `reducedDoom` caps how far the doom treatment and creature can surface.
/// - `reducedMotion` removes the cross-fade animation (a still reveal).
struct SceneRevealView: View {
    let sceneID: String
    let creatureID: String
    let theme: Theme
    let stir: Double
    let reducedDoom: Bool
    let reducedMotion: Bool
    /// Equipped Shrine palette id (nil = the scene's natural colors).
    var paletteID: String? = nil

    private var intensity: Double {
        let clamped = min(max(stir, 0), 1)
        return reducedDoom ? min(clamped, 0.5) : clamped
    }

    /// How visible the hidden creature is; stays invisible until stir builds.
    private var creatureAppear: Double { smoothstep(0.15, 0.85, intensity) }

    var body: some View {
        Group {
            if let sceneAsset = BundledVisuals.assetName(kind: .scene, id: sceneID) {
                realArt(sceneAsset)
            } else {
                RevealBackgroundView(
                    sceneID: sceneID, creatureID: creatureID, stir: stir,
                    reducedDoom: reducedDoom, reducedMotion: reducedMotion
                )
            }
        }
        .hueRotation(palette.hue)
        .overlay(
            palette.tint
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .accessibilityHidden(true)
    }

    /// Equipped-palette treatment: a gentle hue shift + translucent cast over
    /// whichever layer is showing (real art or procedural fallback).
    private var palette: (hue: Angle, tint: Color) {
        switch paletteID {
        case "palette-ember":   return (.degrees(-10), Color.orange.opacity(0.12))
        case "palette-moonlit": return (.degrees(15), Color.blue.opacity(0.14))
        case "palette-bloom":   return (.degrees(0), Color.pink.opacity(0.10))
        default:                return (.degrees(0), Color.clear)
        }
    }

    private func realArt(_ sceneAsset: String) -> some View {
        ZStack {
            GeneratedImageView(
                request: VisualRequest(id: sceneID, theme: theme, kind: .scene),
                maxPixel: 1024
            ) {
                Image(sceneAsset).resizable().scaledToFill()
            }
                .saturation(1 - intensity * 0.5)                 // color drains toward doom
                .overlay(Color.red.opacity(intensity * 0.14))    // faint blood cast
                .overlay(Color.black.opacity(intensity * 0.42))  // deepening gloom
                .ignoresSafeArea()

            if creatureAppear > 0.001,
               let creatureAsset = BundledVisuals.assetName(kind: .creature, id: creatureID) {
                GeneratedImageView(
                    request: VisualRequest(id: creatureID, theme: theme, kind: .creature),
                    maxPixel: 768,
                    contentMode: .fit
                ) {
                    Image(creatureAsset).resizable().scaledToFit()
                }
                    .padding(36)
                    .opacity(creatureAppear * 0.92)
                    .scaleEffect(0.88 + 0.14 * creatureAppear)
                    .shadow(color: .black.opacity(0.6), radius: 24)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            RadialGradient(
                colors: [.clear, .black.opacity(0.15 + intensity * 0.5)],
                center: .center, startRadius: 90, endRadius: 560
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
        .animation(reducedMotion ? nil : .easeInOut(duration: 0.6), value: intensity)
        .clipped()
    }
}

/// Smooth Hermite interpolation: 0 below `edge0`, 1 above `edge1`.
private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}
