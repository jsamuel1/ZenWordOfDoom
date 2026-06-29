import SwiftUI
import LevelKit

/// Routes the between-levels cut scene. Resolves the `CutSceneData` for the just
/// cleared level, renders `CutSceneView`, and on continue advances navigation:
/// if there is a next level it replaces the stack with `[.levelSelect, .game(next)]`
/// (so cut scenes never accumulate on the back stack), otherwise it pops to root.
struct CutSceneContainerView: View {
    let afterLevelID: String

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let cutScene = LevelLibrary.cutScene(afterLevelID: afterLevelID) {
                CutSceneView(
                    cutScene: cutScene,
                    reducedDoom: settings.reducedDoom,
                    reducedMotion: reduceMotion,
                    onContinue: advance
                )
            } else {
                // No breath authored for this level: advance immediately so the
                // player is never stranded.
                Color.clear.onAppear(perform: advance)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func advance() {
        if let next = LevelLibrary.nextLevelID(after: afterLevelID) {
            router.path = [.levelSelect, .game(levelID: next)]
        } else {
            router.popToRoot()
        }
    }
}
