import Foundation
import Combine
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// On-device voice input for speaking the words you find.
///
/// Wraps `SFSpeechRecognizer` + `AVAudioEngine`. Recognition prefers on-device
/// processing whenever the recognizer reports it is supported, so audio never
/// leaves the device. Every Speech/AVFoundation entry point is guarded so the
/// type still compiles on platforms (or build configurations) that lack the
/// frameworks, and every public method degrades to a graceful no-op when the
/// user has not granted permission or the recognizer is unavailable.
@MainActor
final class VoiceInput: ObservableObject {
    /// True while the audio engine is running and we are actively transcribing.
    @Published private(set) var isListening: Bool = false
    /// The most recent (partial or final) transcript, if any.
    @Published private(set) var lastTranscript: String?

    #if canImport(Speech) && canImport(AVFoundation) && !os(macOS)
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init() {
        // Use the device's current locale when supported, otherwise fall back to
        // the default recognizer. Either may be nil if no recognizer exists for
        // the locale; `start` handles that case gracefully.
        self.recognizer = SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer()
    }
    #else
    init() {}
    #endif

    // MARK: Authorization

    /// Requests both speech-recognition and microphone permission. Returns true
    /// only when both are granted; otherwise the caller should not attempt to
    /// start listening. Safe to call repeatedly.
    func requestAuthorization() async -> Bool {
        #if canImport(Speech) && canImport(AVFoundation) && !os(macOS)
        let speechOK = await Self.requestSpeechAuthorization()
        guard speechOK else { return false }
        let micOK = await Self.requestMicrophoneAuthorization()
        return micOK
        #else
        return false
        #endif
    }

    #if canImport(Speech) && canImport(AVFoundation) && !os(macOS)
    private static func requestSpeechAuthorization() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private static func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            // `AVAudioApplication.requestRecordPermission` is the modern API
            // (iOS 17+); fall back to the deprecated session API otherwise.
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    #endif

    // MARK: Listening

    /// Begins listening. Transcripts are delivered to `onResult` on the main
    /// actor for every partial and final result. No-ops (and leaves
    /// `isListening` false) if permission is missing, the recognizer is
    /// unavailable, or audio setup fails.
    func start(onResult: @escaping (String) -> Void) {
        #if canImport(Speech) && canImport(AVFoundation) && !os(macOS)
        guard !isListening else { return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return }
        guard let recognizer, recognizer.isAvailable else { return }

        // Configure the session for recording *before* touching
        // `audioEngine.inputNode` (including inside `resetEngine`, below):
        // querying/resetting the input node while the session is still in a
        // playback-only category latches a stale, recording-incapable format
        // onto the node that survives the category switch and crashes the
        // process when the tap is installed or the engine is started.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            cleanup()
            return
        }

        // Tear down any lingering state before starting fresh.
        resetEngine()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keep audio on-device whenever the recognizer supports it.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // A zero-channel format means there is no usable input; bail out.
        guard format.channelCount > 0 else {
            cleanup()
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Hop to the main actor: the callback may arrive on a background queue.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    self.lastTranscript = transcript
                    onResult(transcript)
                    if result.isFinal {
                        self.stop()
                    }
                }
                if error != nil {
                    self.stop()
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cleanup()
            return
        }
        isListening = true
        #else
        // Speech/AVFoundation unavailable: graceful no-op.
        _ = onResult
        #endif
    }

    /// Stops listening and releases audio resources. Safe to call when not
    /// listening.
    func stop() {
        #if canImport(Speech) && canImport(AVFoundation) && !os(macOS)
        guard isListening || task != nil || request != nil else { return }
        request?.endAudio()
        task?.cancel()
        cleanup()
        isListening = false
        #endif
    }

    #if canImport(Speech) && canImport(AVFoundation) && !os(macOS)
    /// Removes the input tap and stops the engine without touching published state.
    private func resetEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    /// Full teardown of the engine, request, task, and audio session.
    private func cleanup() {
        resetEngine()
        request = nil
        task = nil
        // Deactivating can throw if the session is already inactive; ignore.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    #endif
}
