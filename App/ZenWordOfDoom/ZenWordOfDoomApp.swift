import SwiftUI

@main
struct ZenWordOfDoomApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = GameStore()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(router)
        }
    }
}
