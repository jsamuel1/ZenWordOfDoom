import SwiftUI
import GameCore
import LevelGen

/// Loads the `Level` for a given id asynchronously via `LevelService`, showing a
/// themed loader until it resolves, then renders the play UI in `GamePlayView`.
struct GameContainerView: View {
    let levelID: String

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var levelService: LevelService

    @State private var loaded: Level?

    var body: some View {
        Group {
            if let level = loaded {
                GamePlayView(level: level, settings: settings, store: store)
            } else {
                LoadingView(theme: levelService.theme(forID: levelID))
            }
        }
        .task {
            loaded = await levelService.level(id: levelID)
        }
    }
}

/// The full play screen for one loaded level. Builds the `GameViewModel`, composes
/// the procedural background, grid, word ribbon, wheel, and HUD, wires voice input,
/// and on completion pushes the cut scene route.
struct GamePlayView: View {
    let level: Level

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var levelService: LevelService

    @StateObject private var model: GameViewModel
    @StateObject private var voice = VoiceInput()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(level: Level, settings: AppSettings, store: GameStore) {
        self.level = level
        _model = StateObject(wrappedValue: GameViewModel(
            level: level,
            validator: SystemDictionary(),
            settings: settings,
            store: store
        ))
    }

    var body: some View {
        ZStack {
            SceneRevealView(
                sceneID: model.level.sceneID,
                creatureID: model.level.creatureID,
                stir: model.stir,
                reducedDoom: settings.reducedDoom,
                reducedMotion: reduceMotion
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                HUDView(
                    score: model.score,
                    serenity: model.serenity,
                    hintCost: model.hintCost,
                    timeRemaining: model.timeRemaining,
                    isListening: voice.isListening,
                    voiceEnabled: settings.voiceEnabled,
                    onHint: {
                        Haptics.reveal()
                        model.useHintRevealCell()
                    },
                    onMicStart: { startListening() },
                    onMicStop: { voice.stop() }
                )

                Text(model.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .animation(.default, value: model.lastMessage)
                    .accessibilityLiveRegion()

                GridView(
                    level: model.level,
                    filledCells: model.filledCells,
                    solvedSlotIDs: model.solvedSlotIDs
                )
                .frame(maxHeight: 380)

                Spacer(minLength: 0)

                WordRibbonView(word: model.currentWord)

                WheelView(
                    tiles: model.level.wheel.tiles,
                    displayOrder: model.displayOrder,
                    selection: model.selection,
                    onTap: { id in
                        Haptics.tap()
                        model.tap(tileID: id)
                    },
                    onSwipeBegin: { id in
                        Haptics.tap()
                        model.swipeBegin(tileID: id)
                    },
                    onSwipeExtend: { id in model.swipeExtend(tileID: id) },
                    onSwipeEnd: { model.swipeEnd() }
                )

                controls
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(packTitle)
        .onAppear { model.startTimerIfDoom() }
        .onDisappear {
            model.invalidate()
            voice.stop()
        }
        .onChange(of: model.isComplete) { _, complete in
            guard complete else { return }
            Haptics.success()
            voice.stop()
            // Hold on the fully revealed creature (stir is now 1) so the reveal
            // payoff is actually seen, then move to the cut scene. Shorter when
            // motion is reduced (a brief still reveal instead of a held beat).
            let hold = reduceMotion ? 0.6 : 1.5
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                router.push(.cutScene(afterLevelID: level.id))
            }
        }
    }

    private var packTitle: String {
        let theme = levelService.theme(forID: level.id).rawValue.capitalized
        let band = level.band.rawValue.capitalized
        return "\(theme) · \(band)"
    }

    private var controls: some View {
        HStack {
            Button("Clear", role: .destructive) { model.clear() }
                .buttonStyle(.bordered)

            Spacer()

            Button {
                Haptics.tap()
                model.shuffle()
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Shuffle letters")

            if !model.bonusWords.isEmpty {
                Text("Bonus: \(model.bonusWords.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Submit") {
                Haptics.tap()
                model.submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selection.count < GameEngine.minWordLength)
        }
    }

    private func startListening() {
        Task {
            let ok = await voice.requestAuthorization()
            guard ok else {
                return
            }
            voice.start(onResult: { transcript in
                model.submitSpoken(transcript)
            })
        }
    }
}

private struct LoadingView: View {
    let theme: Theme
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(theme == .zen ? "Composing the garden…" : "Stirring the doom…")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private extension View {
    /// Marks dynamic status text as a live region for VoiceOver where available.
    @ViewBuilder
    func accessibilityLiveRegion() -> some View {
        self.accessibilityAddTraits(.updatesFrequently)
    }
}
