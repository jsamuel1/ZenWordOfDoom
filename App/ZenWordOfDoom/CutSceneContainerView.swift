import SwiftUI
import LevelKit
import LevelGen

struct CutSceneContainerView: View {
    let afterLevelID: String

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var levelService: LevelService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cutScene: CutSceneData?

    var body: some View {
        Group {
            if let cutScene {
                CutSceneView(
                    cutScene: cutScene,
                    reducedDoom: settings.reducedDoom,
                    reducedMotion: reduceMotion,
                    onContinue: advance
                )
            } else {
                Color.clear
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
