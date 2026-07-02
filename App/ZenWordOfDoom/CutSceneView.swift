import SwiftUI
import LevelKit
import LevelGen

/// A between-levels "breath". A gently moving, asset-free procedural zen scene
/// carries a twisted haiku displayed calmly and readably. After
/// `cutScene.popoutDelay` seconds a Doom creature silhouette telegraphs, pops
/// out of the scene, holds briefly, then recedes. The whole thing is skippable
/// (tap anywhere / Continue button) which calls `onContinue`.
///
/// `reducedDoom` softens and ultimately omits the pop-out; `reducedMotion`
/// shows a still reveal with no animation. The poem is exposed to VoiceOver as a
/// single readable element.
struct CutSceneView: View {
    let cutScene: CutSceneData
    let theme: Theme
    let reducedDoom: Bool
    let reducedMotion: Bool
    /// While true the breath cannot be skipped: the Continue button is hidden
    /// and tap-to-continue is ignored (an ad is occupying the slot).
    let continueLocked: Bool
    let onContinue: () -> Void
    /// Fired at the creature pop-out moment (for the audio sting). Not called
    /// under reduced motion (there is no lunge to accompany).
    let onPopout: () -> Void

    /// 0 = calm scene, 1 = full pop-out, easing back toward ~0.4 as it recedes.
    @State private var doom: Double = 0
    /// Drives the ambient drift of the scene (clouds, ripples) when motion is on.
    @State private var drift: Double = 0
    /// Gentle reveal of the poem lines, staggered.
    @State private var poemReveal: Double = 0
    @State private var didPopOut = false

    init(
        cutScene: CutSceneData,
        theme: Theme,
        reducedDoom: Bool,
        reducedMotion: Bool,
        continueLocked: Bool = false,
        onContinue: @escaping () -> Void,
        onPopout: @escaping () -> Void = {}
    ) {
        self.cutScene = cutScene
        self.theme = theme
        self.reducedDoom = reducedDoom
        self.reducedMotion = reducedMotion
        self.continueLocked = continueLocked
        self.onContinue = onContinue
        self.onPopout = onPopout
    }

    /// How strong the doom presence is allowed to get given accessibility prefs.
    private var doomCap: Double {
        reducedDoom ? 0.35 : 1.0
    }

    var body: some View {
        ZStack {
            GeneratedImageView(request: VisualRequest(id: cutScene.scene, theme: theme, kind: .scene),
                               maxPixel: 768) {
                Color.clear
            }
            .opacity(0.5)
            .ignoresSafeArea()

            scene
                .ignoresSafeArea()

            VStack {
                Spacer(minLength: 0)
                poemCard
                Spacer(minLength: 0)
                if !continueLocked {
                    continueButton
                }
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !continueLocked else { return }
            onContinue()
        }
        .task { await runTimeline() }
    }

    // MARK: - Procedural scene

    private var scene: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? nil : 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                draw(in: &context, size: size, time: t)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let d = min(doom, doomCap)

        // Sky / ground gradient: calm cool tones shifting toward a bruised dusk
        // as doom rises.
        let calmTop = Color(red: 0.62, green: 0.74, blue: 0.78)
        let calmBottom = Color(red: 0.86, green: 0.83, blue: 0.74)
        let doomTop = Color(red: 0.18, green: 0.10, blue: 0.16)
        let doomBottom = Color(red: 0.36, green: 0.16, blue: 0.14)
        let top = mix(calmTop, doomTop, d)
        let bottom = mix(calmBottom, doomBottom, d)

        let bg = Gradient(colors: [top, bottom])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                bg,
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // A low "horizon" band of ground / raked sand.
        let horizonY = size.height * 0.62
        var ground = Path()
        ground.addRect(CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY))
        let groundColor = mix(Color(red: 0.80, green: 0.76, blue: 0.66), Color(red: 0.10, green: 0.07, blue: 0.09), d)
        context.fill(ground, with: .color(groundColor))

        // Drifting raked-sand ripples / water lines.
        let lineColor = mix(Color.white.opacity(0.25), Color.red.opacity(0.18), d)
        let phase = CGFloat(sin(time * 0.4)) * (reducedMotion ? 0 : 1)
        for i in 0..<6 {
            let baseY = horizonY + CGFloat(i + 1) * (size.height - horizonY) / 7
            var line = Path()
            let amp = (6 + CGFloat(i) * 2)
            line.move(to: CGPoint(x: 0, y: baseY))
            var x: CGFloat = 0
            while x <= size.width {
                let y = baseY + sin((x / size.width) * .pi * 3 + phase + CGFloat(i)) * amp * 0.3
                line.addLine(to: CGPoint(x: x, y: y))
                x += 8
            }
            context.stroke(line, with: .color(lineColor), lineWidth: 1.5)
        }

        // A serene moon/sun disc that drifts and reddens with doom.
        let discCenter = CGPoint(
            x: size.width * (0.7 + (reducedMotion ? 0 : CGFloat(sin(time * 0.15)) * 0.03)),
            y: size.height * 0.22
        )
        let discColor = mix(Color.white.opacity(0.85), Color.red.opacity(0.7), d)
        let discRect = CGRect(
            x: discCenter.x - 36, y: discCenter.y - 36, width: 72, height: 72
        )
        context.fill(Path(ellipseIn: discRect), with: .color(discColor))

        // Hidden creature silhouette: fades / rises from the ground as doom peaks.
        if d > 0.02 {
            drawCreature(in: &context, size: size, horizonY: horizonY, doom: d, time: time)
        }

        // A vignette that darkens with doom.
        if d > 0.05 {
            let vignette = Gradient(colors: [Color.clear, Color.black.opacity(0.5 * d)])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    vignette,
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: size.width * 0.25,
                    endRadius: size.width * 0.75
                )
            )
        }
    }

    /// A simple procedural silhouette: a hunched body with two glowing eyes that
    /// rises from behind the horizon as `doom` increases.
    private func drawCreature(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        doom d: Double,
        time: TimeInterval
    ) {
        let rise = CGFloat(d)
        let bob = reducedMotion ? 0 : CGFloat(sin(time * 1.6)) * 3 * rise
        let cx = size.width * 0.5
        // Body emerges upward from the horizon.
        let bodyHeight = size.height * 0.30 * rise
        let bodyTop = horizonY - bodyHeight + bob
        let bodyWidth = size.width * 0.34

        var body = Path()
        body.addRoundedRect(
            in: CGRect(
                x: cx - bodyWidth / 2,
                y: bodyTop,
                width: bodyWidth,
                height: horizonY - bodyTop + 40
            ),
            cornerSize: CGSize(width: bodyWidth * 0.5, height: bodyWidth * 0.4)
        )
        context.fill(body, with: .color(Color.black.opacity(0.65 * d)))

        // Two glowing eyes near the top of the emerging head.
        if rise > 0.25 {
            let eyeY = bodyTop + bodyHeight * 0.22
            let eyeGlow = mix(Color.orange, Color.red, d).opacity(min(1, (d - 0.2) * 2))
            for dx in [-bodyWidth * 0.14, bodyWidth * 0.14] {
                let eye = CGRect(x: cx + dx - 5, y: eyeY - 4, width: 10, height: 8)
                context.fill(Path(ellipseIn: eye), with: .color(eyeGlow))
            }
        }
    }

    private func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let tt = max(0, min(1, t))
        let ca = a.resolveComponents()
        let cb = b.resolveComponents()
        return Color(
            red: ca.r + (cb.r - ca.r) * tt,
            green: ca.g + (cb.g - ca.g) * tt,
            blue: ca.b + (cb.b - ca.b) * tt,
            opacity: ca.a + (cb.a - ca.a) * tt
        )
    }

    // MARK: - Poem

    private var poemCard: some View {
        VStack(spacing: 10) {
            ForEach(Array(cutScene.poem.enumerated()), id: \.offset) { idx, line in
                Text(line)
                    .font(.title3.weight(.regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .opacity(lineOpacity(idx))
                    .offset(y: reducedMotion ? 0 : (1 - lineOpacity(idx)) * 10)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 26)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.28))
        )
        .shadow(radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cutScene.poem.joined(separator: ", "))
    }

    private func lineOpacity(_ index: Int) -> Double {
        if reducedMotion { return 1 }
        // Stagger each line in over the reveal progress.
        let count = max(1, cutScene.poem.count)
        let slice = 1.0 / Double(count)
        let start = Double(index) * slice
        let local = (poemReveal - start) / slice
        return max(0, min(1, local))
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white.opacity(0.9))
        .foregroundStyle(.black)
        .accessibilityHint("Skip the breath and go to the next level")
    }

    // MARK: - Lifecycle

    /// Single cancellable task timeline replacing the old chained
    /// `DispatchQueue.main.asyncAfter` calls, which kept firing (including the
    /// pop-out audio sting) even after the player navigated away. `.task`
    /// cancels automatically on disappear, and `Task.sleep` throws on
    /// cancellation, so each `guard` below exits cleanly instead of mutating
    /// state or invoking callbacks on a torn-down view.
    private func runTimeline() async {
        guard !didPopOut else { return }
        didPopOut = true

        if reducedMotion {
            poemReveal = 1
            doom = reducedDoom ? 0 : 0.35
            return
        }

        withAnimation(.easeOut(duration: 1.6)) { poemReveal = 1 }
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { drift = 1 }

        let delay = max(0.5, cutScene.popoutDelay)
        guard (try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))) != nil else { return }

        withAnimation(.easeIn(duration: 0.9)) { doom = min(0.45, doomCap) }   // telegraph
        guard (try? await Task.sleep(nanoseconds: 900_000_000)) != nil else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { doom = doomCap }
        onPopout()                                                            // sting at the lunge
        guard (try? await Task.sleep(nanoseconds: 1_200_000_000)) != nil else { return }

        withAnimation(.easeInOut(duration: 1.4)) { doom = min(0.4, doomCap) } // recede
    }
}

// MARK: - Color component resolution

private extension Color {
    /// Best-effort RGBA components for linear interpolation. Falls back to gray.
    func resolveComponents() -> (r: Double, g: Double, b: Double, a: Double) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Double(r), Double(g), Double(b), Double(a))
        }
        #endif
        return (0.5, 0.5, 0.5, 1.0)
    }
}
