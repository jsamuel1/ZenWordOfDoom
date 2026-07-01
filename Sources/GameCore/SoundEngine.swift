import Foundation

/// The two musical moods. Kept independent of `LevelGen.Theme` so GameCore stays
/// dependency-free; the app maps its theme onto this.
public enum MusicMood: Sendable, Equatable {
    case zen
    case doom
}

/// One-shot sound effects.
public enum SoundCue: Sendable, Equatable {
    case wordLand      // a grid word landed
    case bonus         // a bonus word
    case invalid       // rejected word
    case hintReveal    // a hint cell revealed
    case levelClear    // level completed
    case cutScenePopout // the cut-scene creature sting
}

/// A generative music state: a scale over a root, plus continuous "edge" (timbre
/// harshness) and drone level. The audio backend renders notes/drone from this.
/// Pure and `Equatable` so the crossover math is unit-testable without any audio.
public struct MusicalPalette: Equatable, Sendable {
    /// Root frequency in Hz.
    public var root: Double
    /// Scale intervals (semitone offsets from the root, within an octave).
    public var scale: [Int]
    /// 0 = soft/pure (zen), 1 = harsh/detuned (doom). Drives the backend timbre.
    public var edge: Double
    /// Drone loudness, 0...1.
    public var droneLevel: Double

    public init(root: Double, scale: [Int], edge: Double, droneLevel: Double) {
        self.root = root
        self.scale = scale
        self.edge = edge
        self.droneLevel = droneLevel
    }

    /// Calm: A3 major pentatonic, no edge.
    public static let zen = MusicalPalette(
        root: 220.0, scale: [0, 2, 4, 7, 9], edge: 0.0, droneLevel: 0.5)
    /// Dread: D3 with minor/tritone colour, full edge.
    public static let doom = MusicalPalette(
        root: 146.83, scale: [0, 1, 5, 6, 8], edge: 1.0, droneLevel: 0.72)

    /// The palette for a mood at a given `stir` (0 calm … 1 full doom). This is
    /// the "reactive doom bus": as stir rises the sound crosses toward doom —
    /// the root sinks, the scale flips to the doom colour past a threshold, and
    /// edge/drone climb. A doom-base level starts darker and pushes further.
    public static func palette(for mood: MusicMood, stir: Double) -> MusicalPalette {
        let base = mood == .zen ? zen : doom
        let t = min(max(stir, 0), 1)
        return MusicalPalette(
            root: lerp(base.root, doom.root, t * 0.6),
            scale: t >= 0.6 ? doom.scale : base.scale,
            edge: min(1, base.edge + t * (mood == .zen ? 0.7 : 0.3)),
            droneLevel: min(1, lerp(base.droneLevel, 0.85, t))
        )
    }

    /// Frequency (Hz) of a scale degree; degrees past the scale wrap into higher
    /// octaves. Degree 0 is the root; one full scale up is an octave (×2).
    public func frequency(degree: Int) -> Double {
        let count = scale.count
        guard count > 0 else { return root }
        let octave = Int(floor(Double(degree) / Double(count)))
        let idx = ((degree % count) + count) % count
        let semis = scale[idx] + 12 * octave
        return root * pow(2.0, Double(semis) / 12.0)
    }
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * min(max(t, 0), 1)
}

/// Backend that plays the generative bed and one-shot cues. The app provides an
/// AVAudioEngine-backed implementation; `NullSoundEngine` is the no-op used by
/// tests, previews, and any context without audio.
public protocol SoundEngine: AnyObject, Sendable {
    /// Begin audio (idempotent). No-op when disabled.
    func start()
    /// Update the generative bed for the current mood + stir.
    func setMood(_ mood: MusicMood, stir: Double)
    /// Play a one-shot cue.
    func play(_ cue: SoundCue)
    /// Enable/disable all audio (wired to the Sound setting).
    func setEnabled(_ enabled: Bool)
    /// Stop and tear down audio.
    func stop()
}

/// No-op engine: the default everywhere audio is unavailable or undesired.
public final class NullSoundEngine: SoundEngine, @unchecked Sendable {
    public init() {}
    public func start() {}
    public func setMood(_ mood: MusicMood, stir: Double) {}
    public func play(_ cue: SoundCue) {}
    public func setEnabled(_ enabled: Bool) {}
    public func stop() {}
}
