import Foundation
import AppTrackingTransparency
import GoogleMobileAds

enum AdConfig {
    /// Native ad unit. Google's published TEST id until the real AdMob account
    /// exists — swap this and `GADApplicationIdentifier` in Info.plist together.
    static let nativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"
    /// How long to wait for a fill before falling back to the house card.
    static let loadTimeout: TimeInterval = 4
}

/// Ad seam: the cut-scene slot asks for a native ad; nil means no fill (the
/// slot falls back to the timed house card, so the player is never trapped).
@MainActor
protocol AdService: AnyObject {
    func loadNativeAd() async -> NativeAd?
}

/// No-ads implementation for previews and any context without the SDK.
final class NullAdService: AdService {
    func loadNativeAd() async -> NativeAd? { nil }
}

/// AdMob-backed native ads. Starts the SDK lazily (premium players never pay
/// the startup cost), asks App Tracking Transparency in context right before
/// the first ad, and serves non-personalized ads unless BOTH the user setting
/// and ATT allow personalization.
@MainActor
final class AdMobAdService: NSObject, AdService {
    private let settings: AppSettings

    private var sdkStarted = false
    private var activeLoader: AdLoader?
    private var loadedAd: NativeAd?
    private var loadFinished = false

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
    }

    func loadNativeAd() async -> NativeAd? {
        guard activeLoader == nil else { return nil }   // one load at a time

        if !sdkStarted {
            sdkStarted = true
            _ = await MobileAds.shared.start()
        }
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        let request = Request()
        let personalized = settings.personalizedAds
            && ATTrackingManager.trackingAuthorizationStatus == .authorized
        if !personalized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }

        let loader = AdLoader(adUnitID: AdConfig.nativeAdUnitID,
                              rootViewController: nil,
                              adTypes: [.native],
                              options: nil)
        loader.delegate = self
        activeLoader = loader
        loadedAd = nil
        loadFinished = false
        loader.load(request)

        // Simple main-actor poll to a deadline; the delegate flips the flag.
        // Avoids continuation-leak subtleties if the SDK never calls back.
        let deadline = Date().addingTimeInterval(AdConfig.loadTimeout)
        while !loadFinished && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        activeLoader = nil
        return loadedAd
    }
}

extension AdMobAdService: NativeAdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        MainActor.assumeIsolated {
            loadedAd = nativeAd
            loadFinished = true
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        MainActor.assumeIsolated {
            loadFinished = true
        }
    }
}

/// Environment holder so the service can be swapped (Null in previews).
@MainActor
final class AdServiceBox: ObservableObject {
    let service: any AdService
    init(service: any AdService) { self.service = service }
}
