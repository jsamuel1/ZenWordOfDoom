import SwiftUI
import GameCore
import LevelKit

/// The full play screen for one level. Resolves the level from its id, builds the
/// `GameViewModel`, composes the procedural background, grid, word ribbon, wheel,
/// and HUD, wires voice input, and on completion pushes the cut scene route.
struct GameContainerView: View {
    let levelID: String

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: GameStore

    @StateObject private var model: GameViewModel
    @StateObject private var voice = VoiceInput()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(levelID: String, settings: AppSettings, store: GameStore) {
        self.levelID = levelID
        let level = LevelLibrary.level(id: levelID) ?? SampleLevel.make()
        _model = StateObject(wrappedValue: GameViewModel(
            level: level,
            validator: SystemDictionary(),
            settings: settings,
            store: store
        ))
    }

    var body: some View {
        ZStack {
            RevealBackgroundView(
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
                .frame(maxHeight: 280)

                Spacer(minLength: 0)

                WordRibbonView(word: model.currentWord)

                WheelView(
                    tiles: model.level.wheel.tiles,
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
            router.push(.cutScene(afterLevelID: levelID))
        }
    }

    private var packTitle: String {
        LevelLibrary.packs().first { $0.levelIDs.contains(levelID) }?.title ?? "Zen Word of Doom"
    }

    private var controls: some View {
        HStack {
            Button("Clear", role: .destructive) { model.clear() }
                .buttonStyle(.bordered)

            Spacer()

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

private extension View {
    /// Marks dynamic status text as a live region for VoiceOver where available.
    @ViewBuilder
    func accessibilityLiveRegion() -> some View {
        self.accessibilityAddTraits(.updatesFrequently)
    }
}
