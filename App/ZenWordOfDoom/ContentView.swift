import SwiftUI

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
            // `.id` ties the view's identity to the level, so navigating from one
            // level to another (e.g. after a cut scene) builds a FRESH view and
            // GameViewModel instead of reusing the finished level's solved board.
            GameContainerView(levelID: levelID)
                .id(levelID)
        case .cutScene(let afterLevelID):
            CutSceneContainerView(afterLevelID: afterLevelID)
                .id(afterLevelID)
        case .bestiary:
            BestiaryView()
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        }
    }
}
