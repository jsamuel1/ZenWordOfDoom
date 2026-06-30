import SwiftUI

@main
struct ZenWordOfDoomApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = GameStore()
    @StateObject private var router = AppRouter()
    @StateObject private var levelService = LevelService()
    @StateObject private var visuals = VisualProviderBox(provider: ImagePlaygroundVisualProvider())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(router)
                .environmentObject(levelService)
                .environmentObject(visuals)
        }
    }
}
