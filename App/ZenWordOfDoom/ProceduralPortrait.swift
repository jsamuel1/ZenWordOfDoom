import SwiftUI

/// Asset-free fallback portrait: a deterministic ominous silhouette derived from
/// the creature id, used until/unless a generated image is available.
struct ProceduralPortrait: View {
    let creatureID: String

    var body: some View {
        Canvas { context, size in
            // Dark themed backdrop.
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(
                            Gradient(colors: [Color(hue: 0.72, saturation: 0.5, brightness: 0.18),
                                              Color(hue: 0.02, saturation: 0.6, brightness: 0.10)]),
                            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            var rng = Hash(creatureID).gen()
            // Blobby silhouette.
            let cx = size.width / 2, cy = size.height * 0.56
            let scale = min(size.width, size.height) * 0.34
            var path = Path()
            let lobes = 9
            var pts: [CGPoint] = []
            for i in 0..<lobes {
                let a = Double(i) / Double(lobes) * 2 * .pi - .pi / 2
                let r = scale * (0.7 + rng.unit() * 0.6)
                pts.append(CGPoint(x: cx + CGFloat(cos(a)) * CGFloat(r),
                                   y: cy + CGFloat(sin(a)) * CGFloat(r) * 1.1))
            }
            if let first = pts.first {
                path.move(to: first)
                for i in 0..<pts.count {
                    let cur = pts[i], nxt = pts[(i + 1) % pts.count]
                    path.addQuadCurve(to: CGPoint(x: (cur.x + nxt.x) / 2, y: (cur.y + nxt.y) / 2), control: cur)
                }
                path.closeSubpath()
            }
            context.fill(path, with: .color(.black.opacity(0.7)))
            // Two glowing eyes.
            let eyeR = scale * 0.09
            for s in [-1.0, 1.0] {
                let ex = cx + CGFloat(s) * scale * 0.24, ey = cy - scale * 0.16
                context.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: ey - eyeR, width: eyeR * 2, height: eyeR * 2)),
                             with: .color(Color(hue: 0.07, saturation: 1, brightness: 1)))
            }
        }
    }

    private struct Hash {
        var s: UInt64
        init(_ str: String) { var h: UInt64 = 1469598103934665603; for b in str.utf8 { h ^= UInt64(b); h = h &* 1099511628211 }; s = h }
        func gen() -> Gen { Gen(state: s) }
        struct Gen { var state: UInt64
            mutating func next() -> UInt64 { state = state &+ 0x9E3779B97F4A7C15; var z = state; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
            mutating func unit() -> Double { Double(next() >> 11) * (1.0 / 9007199254740992.0) }
        }
    }
}
