import Foundation
import Combine

/// User-tunable preferences, persisted manually to `UserDefaults`. Each
/// `@Published` property writes through on `didSet` so changes survive relaunch
/// without any explicit save call.
final class AppSettings: ObservableObject {

    private enum Key {
        static let reducedDoom = "settings.reducedDoom"
        static let voiceEnabled = "settings.voiceEnabled"
        static let firstLetterHints = "settings.firstLetterHints"
        static let soundEnabled = "settings.soundEnabled"
        static let doomMode = "settings.doomMode"
    }

    private let defaults: UserDefaults

    @Published var reducedDoom: Bool {
        didSet { defaults.set(reducedDoom, forKey: Key.reducedDoom) }
    }
    @Published var voiceEnabled: Bool {
        didSet { defaults.set(voiceEnabled, forKey: Key.voiceEnabled) }
    }
    @Published var firstLetterHints: Bool {
        didSet { defaults.set(firstLetterHints, forKey: Key.firstLetterHints) }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }
    @Published var doomMode: Bool {
        didSet { defaults.set(doomMode, forKey: Key.doomMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Defaults registered so first launch matches the spec'd values.
        defaults.register(defaults: [
            Key.reducedDoom: false,
            Key.voiceEnabled: true,
            Key.firstLetterHints: false,
            Key.soundEnabled: true,
            Key.doomMode: false,
        ])
        self.reducedDoom = defaults.bool(forKey: Key.reducedDoom)
        self.voiceEnabled = defaults.bool(forKey: Key.voiceEnabled)
        self.firstLetterHints = defaults.bool(forKey: Key.firstLetterHints)
        self.soundEnabled = defaults.bool(forKey: Key.soundEnabled)
        self.doomMode = defaults.bool(forKey: Key.doomMode)
    }
}
