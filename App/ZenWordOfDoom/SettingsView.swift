import SwiftUI

/// Edits the shared `AppSettings`. Toggles bind directly; persistence happens
/// in `AppSettings`'s `didSet`.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var storeService: StoreKitStoreService

    @State private var restoring = false
    @State private var restoreMessage: String?

    var body: some View {
        Form {
            Section {
                RemoveAdsButton()
                Button {
                    restoring = true
                    restoreMessage = nil
                    Task {
                        await storeService.restore()
                        restoring = false
                        restoreMessage = storeService.isPremium
                            ? "Purchases restored."
                            : "No previous purchases found."
                    }
                } label: {
                    HStack {
                        Text("Restore Purchases")
                        Spacer()
                        if restoring { ProgressView() }
                    }
                }
                .disabled(restoring)

                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !storeService.isPremium {
                    Toggle("Personalized Ads", isOn: $settings.personalizedAds)
                    Text("Off means the ads between levels are generic instead of tailored. Nothing else changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Store")
            } footer: {
                Text("Every level is free. Ads appear only between levels after the first pack; removing them is a one-time purchase.")
            }

            Section("Mode") {
                Toggle("Doom Mode", isOn: $settings.doomMode)
                Text("Race the clock. If the doom outlasts you, the level still opens the path — but its points are forfeit. Zen mode is untimed.")
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
