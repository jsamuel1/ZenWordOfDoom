import AVFoundation
import GameCore

/// AVFoundation-backed generative audio. A single `AVAudioSourceNode` renders a
/// continuous drone plus a slow arpeggio derived from the current
/// `MusicalPalette` (updated by `setMood` as stir changes — the reactive doom
/// bus), and short one-shot cue voices. No external dependency; audio can't be
/// verified in CI/simulator here, so this is best-effort and fully guarded.
final class AVAudioSoundEngine: SoundEngine, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let sampleRate: Double = 44_100

    private var started = false
    private var enabled = true

    /// Heap-allocated lock so the audio thread and main thread share one stable
    /// address (the correct `os_unfair_lock` usage pattern).
    private let lock: UnsafeMutablePointer<os_unfair_lock> = {
        let p = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        p.initialize(to: os_unfair_lock())
        return p
    }()

    // State shared with the render thread (guarded by `lock`).
    private var palette = MusicalPalette.zen
    private var dronePhaseA = 0.0, dronePhaseB = 0.0, dronePhaseDetune = 0.0
    private var arpPhase = 0.0, arpFreq = 220.0, arpEnv = 0.0
    private var samplesToNextNote = 0
    private var cuePhase = 0.0, cueFreq = 0.0, cueEnv = 0.0, cueDecay = 0.999, cueNoise = 0.0
    private var rngState: UInt64 = 0x2545F4914F6CDD1D

    deinit { lock.deallocate() }

    // MARK: - SoundEngine

    func start() {
        guard !started else { applyEnabled(); return }
        configureSession()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            self?.render(frameCount: frameCount, abl: abl)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
        applyEnabled()
        do { try engine.start(); started = true } catch { started = false }
    }

    func setMood(_ mood: MusicMood, stir: Double) {
        let p = MusicalPalette.palette(for: mood, stir: stir)
        locked { palette = p }
    }

    func play(_ cue: SoundCue) {
        guard enabled else { return }
        let v = Self.voice(for: cue)
        locked {
            cueFreq = v.freq; cueDecay = v.decay; cueNoise = v.noise
            cueEnv = 1.0; cuePhase = 0
        }
    }

    func setEnabled(_ isOn: Bool) {
        enabled = isOn
        applyEnabled()
    }

    func stop() {
        guard started else { return }
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
        started = false
    }

    // MARK: - Internals

    private func applyEnabled() {
        guard started else { return }
        engine.mainMixerNode.outputVolume = enabled ? 1 : 0
    }

    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // Ambient + mix: respects the silent switch and doesn't stop other audio.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    /// (frequency, per-sample decay, noise amount) for each cue.
    private static func voice(for cue: SoundCue) -> (freq: Double, decay: Double, noise: Double) {
        switch cue {
        case .wordLand:       return (523.25, 0.9990, 0.00)  // C5 chime
        case .bonus:          return (783.99, 0.9992, 0.05)  // G5 sparkle
        case .invalid:        return (110.00, 0.9975, 0.40)  // low buzz
        case .hintReveal:     return (659.25, 0.9990, 0.00)  // E5
        case .levelClear:     return (659.25, 0.99965, 0.00) // long, bright
        case .cutScenePopout: return (98.00,  0.9985, 0.60)  // low sting
        }
    }

    private func nextRandom() -> UInt64 {
        rngState ^= rngState >> 12
        rngState ^= rngState << 25
        rngState ^= rngState >> 27
        return rngState &* 0x2545F4914F6CDD1D
    }

    private func render(frameCount: AVAudioFrameCount, abl: UnsafeMutablePointer<AudioBufferList>) {
        // Snapshot shared state once per render call.
        os_unfair_lock_lock(lock)
        let p = palette
        var dpA = dronePhaseA, dpB = dronePhaseB, dpD = dronePhaseDetune
        var ap = arpPhase, aFreq = arpFreq, aEnv = arpEnv, toNext = samplesToNextNote
        var cp = cuePhase, cEnv = cueEnv
        let cFreq = cueFreq, cDecay = cueDecay, cNoise = cueNoise
        os_unfair_lock_unlock(lock)

        let sr = sampleRate
        let twoPi = 2.0 * Double.pi
        let dInc = twoPi * p.root / sr
        let fifthInc = twoPi * (p.root * 1.5) / sr
        let detuneInc = twoPi * (p.root * 1.007) / sr
        let notePeriod = Int(sr * 0.7)
        let droneGain = 0.12 * p.droneLevel
        let edge = p.edge

        for buffer in UnsafeMutableAudioBufferListPointer(abl) {
            let out = buffer.mData!.assumingMemoryBound(to: Float.self)
            for frame in 0..<Int(frameCount) {
                var s = sin(dpA) + 0.6 * sin(dpB)
                s += edge * (0.4 * sin(dpA * 2) + 0.3 * sin(dpD))
                s *= droneGain

                if toNext <= 0 {
                    let deg = Int(nextRandom() % 5) + Int(nextRandom() % 2) * 5
                    aFreq = p.frequency(degree: deg)
                    aEnv = 1.0
                    ap = 0
                    toNext = notePeriod
                }
                s += aEnv * sin(ap) * 0.10

                if cEnv > 0.0005 {
                    let noise = cNoise > 0 ? (Double(nextRandom() % 1000) / 500.0 - 1.0) * cNoise : 0
                    s += cEnv * (sin(cp) + noise) * 0.18
                }

                s = max(-1, min(1, s))
                out[frame] = Float(s)

                dpA += dInc; dpB += fifthInc; dpD += detuneInc
                ap += twoPi * aFreq / sr
                cp += twoPi * cFreq / sr
                aEnv *= 0.9994
                cEnv *= cDecay
                toNext -= 1
            }
        }

        os_unfair_lock_lock(lock)
        dronePhaseA = dpA.truncatingRemainder(dividingBy: twoPi)
        dronePhaseB = dpB.truncatingRemainder(dividingBy: twoPi)
        dronePhaseDetune = dpD.truncatingRemainder(dividingBy: twoPi)
        arpPhase = ap; arpFreq = aFreq; arpEnv = aEnv; samplesToNextNote = toNext
        cuePhase = cp; cueEnv = cEnv
        os_unfair_lock_unlock(lock)
    }

    private func locked(_ body: () -> Void) {
        os_unfair_lock_lock(lock); body(); os_unfair_lock_unlock(lock)
    }
}

/// Environment holder so the engine can be injected and swapped (Null in tests).
@MainActor
final class SoundEngineBox: ObservableObject {
    let engine: any SoundEngine
    init(engine: any SoundEngine) { self.engine = engine }
}
