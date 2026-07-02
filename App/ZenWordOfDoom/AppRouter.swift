import Foundation
import Combine

/// A navigable destination in the app's single `NavigationStack`.
enum Screen: Hashable {
    case levelSelect
    case game(levelID: String)
    case cutScene(afterLevelID: String)
    case bestiary
    case shrine
    case stats
    case settings
}

/// Drives navigation. The stack is rooted at `MenuView`; `path` holds the
/// pushed screens.
@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [Screen] = []

    func push(_ screen: Screen) {
        path.append(screen)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
