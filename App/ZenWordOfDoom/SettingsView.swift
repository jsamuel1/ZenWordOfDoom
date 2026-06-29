import SwiftUI

/// Edits the shared `AppSettings`. Toggles bind directly; persistence happens
/// in `AppSettings`'s `didSet`.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: GameStore

    var body: some View {
        Form {
            Section("Mode") {
                Toggle("Doom Mode", isOn: $settings.doomMode)
                Text("Doom mode adds a ticking time limit. Zen mode is untimed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Atmosphere") {
                Toggle("Reduced Doom", isOn: $settings.reducedDoom)
                Toggle("Sound", isOn: $settings.soundEnabled)
            }

            Section("Assistance") {
                Toggle("Voice Input", isOn: $settings.voiceEnabled)
                Toggle("First-Letter Hints", isOn: $settings.firstLetterHints)
            }

            Section("Profile") {
                LabeledContent("Serenity", value: "\(store.state.serenity)")
                LabeledContent("Levels Cleared", value: "\(store.state.stats.levelsCleared)")
                LabeledContent("Words Found", value: "\(store.state.stats.totalWordsFound)")
                LabeledContent("Best Streak", value: "\(store.state.stats.bestStreak)")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
