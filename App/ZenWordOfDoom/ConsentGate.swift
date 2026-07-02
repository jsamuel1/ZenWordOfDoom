import Foundation
import UIKit
import UserMessagingPlatform

/// GDPR/UK-GDPR/Swiss consent seam. `gatherConsent()` runs once at launch,
/// well before the player ever reaches an ad-gated cut scene (packs 1-10 are
/// ad-free, so there's ample time); `canRequestAds` then gates every ad load.
/// Outside the EEA/UK/Switzerland — or before a console message is published —
/// this resolves to "no consent needed" and ads proceed exactly as before.
@MainActor
protocol ConsentGate: AnyObject {
    /// True once ads may legally be requested: either no consent was required,
    /// or the player has made a choice. False blocks ad loading, never blocks
    /// gameplay — `AdMobAdService` falls back to the house card either way.
    var canRequestAds: Bool { get }
    /// GDPR requires letting users revisit their choice; true only when the
    /// published message calls for a durable entry point (Settings surfaces it).
    var privacyOptionsRequired: Bool { get }

    func gatherConsent() async
    func presentPrivacyOptions() async
}

/// No-op gate for tests/previews and any context without the SDK: always
/// permits ads, matching the "no message published yet" real-world default.
final class NullConsentGate: ConsentGate {
    var canRequestAds: Bool { true }
    var privacyOptionsRequired: Bool { false }
    func gatherConsent() async {}
    func presentPrivacyOptions() async {}
}

/// Google UMP-backed implementation.
final class UMPConsentGate: ConsentGate {
    var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }
    var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    func gatherConsent() async {
        let parameters = RequestParameters()
        #if DEBUG
        // Force EEA behavior in debug builds only — Release/TestFlight/App
        // Store builds always resolve the player's real geography. Add this
        // device's hashed test identifier (printed to the Xcode console on
        // first debug run) below to see the message on a physical device;
        // the Simulator honors the geography override without one.
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        debugSettings.testDeviceIdentifiers = []
        parameters.debugSettings = debugSettings
        #endif

        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }
        guard let vc = Self.rootViewController() else { return }
        _ = try? await ConsentForm.loadAndPresentIfRequired(from: vc)
    }

    func presentPrivacyOptions() async {
        guard let vc = Self.rootViewController() else { return }
        _ = try? await ConsentForm.presentPrivacyOptionsForm(from: vc)
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController
    }
}

/// Environment holder so the gate can be swapped (Null in tests/previews).
@MainActor
final class ConsentGateBox: ObservableObject {
    let gate: any ConsentGate
    init(gate: any ConsentGate) { self.gate = gate }
}
