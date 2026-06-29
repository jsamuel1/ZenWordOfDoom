import SwiftUI
import LevelKit

/// The app root: a single `NavigationStack` driven by `AppRouter.path`, rooted
/// at `MenuView`. Each `Screen` maps to its destination view here.
struct ContentView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: GameStore

    var body: some View {
        NavigationStack(path: $router.path) {
            MenuView()
                .navigationDestination(for: Screen.self) { screen in
                    destination(for: screen)
                }
        }
    }

    @ViewBuilder
    private func destination(for screen: Screen) -> some View {
        switch screen {
        case .levelSelect:
            LevelSelectView()
        case .game(let levelID):
            GameContainerView(levelID: levelID, settings: settings, store: store)
        case .cutScene(let afterLevelID):
            CutSceneContainerView(afterLevelID: afterLevelID)
        case .bestiary:
            BestiaryView()
        case .settings:
            SettingsView()
        }
    }
}
