import SwiftUI
import LevelGen

/// The home screen. Play descends into level select; secondary buttons reach
/// the bestiary and settings.
struct MenuView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: GameStore

    @State private var showSerenitySheet = false

    /// Hero illustrations depicting the game's "Zen meets Doom" premise. One is
    /// picked per launch (stable for the session) as the title screen backdrop.
    /// `static` so the choice survives MenuView being re-created on every
    /// return to the menu, instead of re-rolling per appearance.
    static let titleArt = [
        "monk-in-ruins", "doom-marine-shrine", "garden-in-the-ruins",
        "monk-on-skulls", "mandala-and-void", "elder-and-volcano",
    ]
    private static let backdrop = titleArt.randomElement() ?? "monk-in-ruins"

    var body: some View {
        ZStack {
            Image(Self.backdrop)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(hue: 0.33, saturation: 0.22, brightness: 0.92).opacity(0.35),
                    Color(hue: 0.55, saturation: 0.30, brightness: 0.45).opacity(0.75),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Zen Word")
                            .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        Text("of Doom")
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .multilineTextAlignment(.center)
                    .shadow(radius: 4)

                    Button {
                        showSerenitySheet = true
                    } label: {
                        Label("Serenity \(store.state.serenity)", systemImage: "leaf.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Get more serenity")

                    dailyCard

                    VStack(spacing: 16) {
                        Button {
                            // Drop straight into the next level to play; if every
                            // level is cleared there's nothing new, so show the list.
                            if let next = store.nextUnclearedLevelID {
                                router.push(.game(levelID: next))
                            } else {
                                router.push(.levelSelect)
                            }
                        } label: {
                            Label("Play", systemImage: "leaf.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            router.push(.levelSelect)
                        } label: {
                            Label("Select Level", systemImage: "square.grid.2x2.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            router.push(.bestiary)
                        } label: {
                            Label("Bestiary", systemImage: "pawprint.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            router.push(.shrine)
                        } label: {
                            Label("Shrine", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            router.push(.stats)
                        } label: {
                            Label("Stats", systemImage: "chart.bar.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            router.push(.settings)
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 40)
                }
                .padding()
                .padding(.top, 48)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSerenitySheet) {
            SerenitySheetView()
        }
    }

    private var dailyCard: some View {
        let dailyID = DailyPuzzle.id(for: Date())
        let cleared = store.isCleared(dailyID)
        let streak = store.state.stats.currentStreak
        return Button {
            router.push(.game(levelID: dailyID))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: cleared ? "checkmark.seal.fill" : "sun.haze.fill")
                    .foregroundStyle(cleared ? .green : .orange)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Doom")
                        .font(.headline)
                    Text(cleared ? "Cleared — the garden rests" : "One puzzle. Every soul. Every day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.orange)
                        .accessibilityLabel("\(streak) day streak")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
    }
}
