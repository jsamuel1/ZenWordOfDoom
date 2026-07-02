import SwiftUI

@main
struct ZenWordOfDoomApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var store: GameStore
    @StateObject private var storeService: StoreKitStoreService
    @StateObject private var adBox: AdServiceBox
    @StateObject private var consentBox: ConsentGateBox
    @StateObject private var router = AppRouter()
    @StateObject private var levelService = LevelService()
    @StateObject private var visuals = VisualProviderBox(provider: ImagePlaygroundVisualProvider())
    @StateObject private var sound = SoundEngineBox(engine: AVAudioSoundEngine())

    init() {
        // The store service delivers verified purchases into the same GameStore
        // instance that owns the persisted SaveState.
        let gameStore = GameStore()
        _store = StateObject(wrappedValue: gameStore)
        _storeService = StateObject(wrappedValue: StoreKitStoreService(
            onEntitlementChange: { premium in gameStore.setPremium(premium) },
            onConsumable: { item, txID in
                gameStore.creditPurchase(item: item, transactionID: txID)
            }
        ))
        // Ads read the personalization setting live, so both share one instance.
        let appSettings = AppSettings()
        _settings = StateObject(wrappedValue: appSettings)
        // The consent gate is asked before every ad load, so both share one
        // instance too (and ContentView gathers consent through the same box).
        let consentGate = UMPConsentGate()
        _consentBox = StateObject(wrappedValue: ConsentGateBox(gate: consentGate))
        _adBox = StateObject(wrappedValue: AdServiceBox(
            service: AdMobAdService(settings: appSettings, consentGate: consentGate)))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(storeService)
                .environmentObject(router)
                .environmentObject(levelService)
                .environmentObject(visuals)
                .environmentObject(sound)
                .environmentObject(adBox)
                .environmentObject(consentBox)
        }
    }
}
