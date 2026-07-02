import SwiftUI
import GameCore
import LevelKit
import LevelGen

struct CutSceneContainerView: View {
    let afterLevelID: String

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var levelService: LevelService
    @EnvironmentObject private var soundBox: SoundEngineBox
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var storeService: StoreKitStoreService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cutScene: CutSceneData?
    /// True once the ad slot has run its course (or no ad applies).
    @State private var adComplete = false

    private var mood: MusicMood {
        levelService.theme(forID: afterLevelID) == .doom ? .doom : .zen
    }

    /// Premium from the live entitlement or the offline SaveState mirror.
    private var isPremium: Bool {
        storeService.isPremium || store.state.premiumUnlocked
    }

    /// Whether this breath carries an ad (free players past pack 1 only).
    private var adGated: Bool {
        let order = levelService.order(forID: afterLevelID) ?? 0
        return AdPolicy.shouldShowAd(afterLevelOrder: order, isPremium: isPremium)
    }

    var body: some View {
        Group {
            if let cutScene {
                CutSceneView(
                    cutScene: cutScene,
                    theme: levelService.theme(forID: afterLevelID),
                    reducedDoom: settings.reducedDoom,
                    reducedMotion: reduceMotion,
                    continueLocked: adGated && !adComplete,
                    onContinue: advance,
                    onPopout: { soundBox.engine.play(.cutScenePopout) }
                )
                .overlay(alignment: .bottom) {
                    if adGated && !adComplete {
                        AdSlotView { adComplete = true }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 90)
                            .transition(.opacity)
                    }
                }
                .onChange(of: storeService.isPremium) { _, premium in
                    // Buying remove-ads from the card frees the breath instantly.
                    if premium { adComplete = true }
                }
            } else {
                Color.clear
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Keep the generative bed alive through the breath (a low, ominous
            // ambiance), so the pop-out sting has an engine to play on.
            soundBox.engine.setEnabled(settings.soundEnabled)
            soundBox.engine.start()
            soundBox.engine.setMood(mood, stir: 0.3)
        }
        .onDisappear { soundBox.engine.stop() }
        .task {
            let level = await levelService.level(id: afterLevelID)
            cutScene = CutSceneFactory.cutScene(
                forLevelID: afterLevelID,
                theme: levelService.theme(forID: afterLevelID),
                order: levelService.order(forID: afterLevelID) ?? 0,
                sceneID: level.sceneID,
                creatureID: level.creatureID,
                poemSet: store.state.equippedPoemSet
            )
        }
    }

    private func advance() {
        if let next = levelService.nextID(after: afterLevelID) {
            router.path = [.levelSelect, .game(levelID: next)]
        } else {
            router.popToRoot()
        }
    }
}
