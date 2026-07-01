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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cutScene: CutSceneData?

    private var mood: MusicMood {
        levelService.theme(forID: afterLevelID) == .doom ? .doom : .zen
    }

    var body: some View {
        Group {
            if let cutScene {
                CutSceneView(
                    cutScene: cutScene,
                    theme: levelService.theme(forID: afterLevelID),
                    reducedDoom: settings.reducedDoom,
                    reducedMotion: reduceMotion,
                    onContinue: advance,
                    onPopout: { soundBox.engine.play(.cutScenePopout) }
                )
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
                creatureID: level.creatureID
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
