import SwiftUI

/// A fully procedural, asset-free background that drifts from a serene zen scene
/// toward a "doom" mood as `stir` rises (0 = calm, 1 = full doom). A hidden
/// creature silhouette fades in with stir so the level's monster is foreshadowed
/// without ever loading an image.
///
/// - `sceneID` / `creatureID` are hashed to deterministic palettes and silhouette
///   shapes, so each level looks distinct but stable across launches.
/// - `reducedDoom` caps how dark/agitated the scene can get.
/// - `reducedMotion` freezes all animation (no drifting gradient, no ripple),
///   showing a still reveal instead.
///
/// Stateless aside from the animation clock; everything derives from the inputs.
struct RevealBackgroundView: View {
    let sceneID: String
    let creatureID: String
    let stir: Double
    let reducedDoom: Bool
    let reducedMotion: Bool

    /// Effective doom intensity after clamping and the reduced-doom cap.
    private var intensity: Double {
        let clamped = min(max(stir, 0), 1)
        return reducedDoom ? min(clamped, 0.5) : clamped
    }

    var body: some View {
        if reducedMotion {
            staticScene
        } else {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                scene(time: t)
            }
        }
    }

    // MARK: - Scene composition

    private var staticScene: some View {
        scene(time: 0)
    }

    private func scene(time: TimeInterval) -> some View {
        let palette = Palette(sceneID: sceneID, intensity: intensity)
        // Gentle breathing offset; zero when motion is reduced (time stays 0).
        let breath = sin(time * 0.4) * 0.5 + 0.5

        return ZStack {
            // Base sky gradient, calm -> doom.
            LinearGradient(
                colors: [palette.top, palette.bottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Drifting mist / energy field rendered procedurally.
            Canvas { context, size in
                drawMist(in: &context, size: size, palette: palette, time: time, breath: breath)
                drawCreature(in: &context, size: size, palette: palette, breath: breath)
                drawSurface(in: &context, size: size, palette: palette, time: time)
            }
            .ignoresSafeArea()
            .blendMode(.plusLighter)

            // Vignette deepens with doom.
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.15 + intensity * 0.45)],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Mist / particles

    private func drawMist(
        in context: inout GraphicsContext,
        size: CGSize,
        palette: Palette,
        time: TimeInterval,
        breath: Double
    ) {
        var rng = SeededHash(sceneID).generator()
        let blobCount = 6
        for i in 0..<blobCount {
            let baseX = rng.unitDouble()
            let baseY = rng.unitDouble()
            let r = rng.unitDouble()
            // Slow drift; stir speeds it up.
            let drift = time * (0.05 + intensity * 0.2) + Double(i)
            let x = (baseX + sin(drift) * 0.06) * size.width
            let y = (baseY + cos(drift * 0.8) * 0.05) * size.height
            let radius = (40 + r * 90) * (0.9 + breath * 0.2)
            let opacity = (0.05 + r * 0.08) * (1 + intensity)
            let rect = CGRect(
                x: x - radius, y: y - radius,
                width: radius * 2, height: radius * 2
            )
            context.fill(
                Circle().path(in: rect),
                with: .color(palette.mist.opacity(min(opacity, 0.35)))
            )
        }
    }

    // MARK: - Hidden creature silhouette

    private func drawCreature(
        in context: inout GraphicsContext,
        size: CGSize,
        palette: Palette,
        breath: Double
    ) {
        // The creature only becomes perceptible as stir builds.
        let appear = smoothstep(0.15, 0.85, intensity)
        guard appear > 0.001 else { return }

        let cx = size.width / 2
        let cy = size.height * 0.46
        let scale = min(size.width, size.height) * 0.32 * (0.95 + breath * 0.05)
        let path = creaturePath(center: CGPoint(x: cx, y: cy), scale: scale)

        // Soft dark silhouette with a faint menacing rim.
        context.fill(path, with: .color(palette.creature.opacity(appear * 0.55)))
        context.stroke(
            path,
            with: .color(palette.creatureRim.opacity(appear * 0.5)),
            lineWidth: 1.5
        )

        // Eyes glow in at higher stir.
        let eyeAppear = smoothstep(0.5, 0.95, intensity)
        if eyeAppear > 0.001 {
            let eyeR = scale * 0.06
            for sign in [-1.0, 1.0] {
                let ex = cx + sign * scale * 0.22
                let ey = cy - scale * 0.18
                let rect = CGRect(x: ex - eyeR, y: ey - eyeR, width: eyeR * 2, height: eyeR * 2)
                context.fill(
                    Circle().path(in: rect),
                    with: .color(palette.eye.opacity(eyeAppear))
                )
            }
        }
    }

    /// A deterministic blobby silhouette derived from `creatureID`. Not meant to
    /// be a specific animal — just an ominous, level-stable shape.
    private func creaturePath(center: CGPoint, scale: CGFloat) -> Path {
        var rng = SeededHash(creatureID).generator()
        let lobes = 9
        var points: [CGPoint] = []
        for i in 0..<lobes {
            let angle = Double(i) / Double(lobes) * 2 * .pi - .pi / 2
            let wobble = 0.7 + rng.unitDouble() * 0.6
            let radius = scale * CGFloat(wobble)
            points.append(CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle)) * 1.1
            ))
        }
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        // Smooth closed curve through the lobe points.
        for i in 0..<points.count {
            let current = points[i]
            let next = points[(i + 1) % points.count]
            let mid = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: current)
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Foreground surface (water / sand line)

    private func drawSurface(
        in context: inout GraphicsContext,
        size: CGSize,
        palette: Palette,
        time: TimeInterval
    ) {
        let baseY = size.height * 0.82
        let amplitude = 6 + intensity * 22
        let speed = 0.6 + intensity * 1.4
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseY))
        let step: CGFloat = 12
        var x: CGFloat = 0
        while x <= size.width {
            let phase = Double(x) / Double(size.width) * 4 * .pi
            let y = baseY + CGFloat(sin(phase + time * speed)) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        context.fill(path, with: .color(palette.surface.opacity(0.5)))
    }
}

// MARK: - Palette

/// Deterministic color palette derived from the scene id and the doom intensity.
private struct Palette {
    let top: Color
    let bottom: Color
    let mist: Color
    let surface: Color
    let creature: Color
    let creatureRim: Color
    let eye: Color

    init(sceneID: String, intensity: Double) {
        // Stable base hue per scene.
        var gen = SeededHash(sceneID).generator()
        let baseHue = gen.unitDouble()
        // Calm scenes sit in cool greens/blues; doom pushes hue toward red and
        // crushes brightness / lifts saturation.
        let doomHue = lerp(baseHue, 0.0, intensity * 0.6) // toward red
        let calmSat = 0.35 + gen.unitDouble() * 0.2
        let sat = lerp(calmSat, 0.8, intensity)
        let bright = lerp(0.55, 0.18, intensity)

        top = Color(hue: doomHue, saturation: sat * 0.7, brightness: bright + 0.18)
        bottom = Color(hue: doomHue, saturation: sat, brightness: bright)
        mist = Color(hue: lerp(baseHue, 0.08, intensity), saturation: 0.3, brightness: 0.9)
        surface = Color(hue: doomHue, saturation: sat, brightness: bright * 0.7)
        creature = Color(hue: doomHue, saturation: 0.6, brightness: 0.06)
        creatureRim = Color(hue: 0.02, saturation: 0.9, brightness: 0.5)
        eye = Color(hue: 0.07, saturation: 1.0, brightness: 1.0)
    }
}

// MARK: - Helpers

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * min(max(t, 0), 1)
}

/// Smooth Hermite interpolation, returning 0 below `edge0`, 1 above `edge1`.
private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

/// Tiny deterministic value source seeded from a string. Used to keep procedural
/// scenes stable per level without depending on GameCore's RNG.
private struct SeededHash {
    let seed: UInt64

    init(_ string: String) {
        var h: UInt64 = 1469598103934665603 // FNV-1a offset basis
        for byte in string.utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211
        }
        seed = h
    }

    func generator() -> ValueGenerator { ValueGenerator(state: seed) }

    struct ValueGenerator {
        var state: UInt64

        /// SplitMix64 step.
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }

        /// Next value in [0, 1).
        mutating func unitDouble() -> Double {
            Double(next() >> 11) * (1.0 / 9007199254740992.0)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        RevealBackgroundView(sceneID: "pond", creatureID: "koi-wraith", stir: 0.1,
                             reducedDoom: false, reducedMotion: false)
        RevealBackgroundView(sceneID: "pond", creatureID: "koi-wraith", stir: 0.9,
                             reducedDoom: false, reducedMotion: false)
    }
}
