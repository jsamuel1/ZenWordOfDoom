import XCTest
@testable import ZenWordOfDoom

/// Controllable fake so we can assert on the wiring between `AdMobAdService`
/// and the consent decision without touching the real UMP/AdMob SDKs.
@MainActor
private final class FakeConsentGate: ConsentGate {
    var canRequestAds: Bool
    var privacyOptionsRequired: Bool = false
    private(set) var gatherConsentCallCount = 0

    init(canRequestAds: Bool) { self.canRequestAds = canRequestAds }

    func gatherConsent() async { gatherConsentCallCount += 1 }
    func presentPrivacyOptions() async {}
}

@MainActor
final class ConsentGateTests: XCTestCase {

    func testNullConsentGateAlwaysPermitsAds() {
        let gate = NullConsentGate()
        XCTAssertTrue(gate.canRequestAds)
        XCTAssertFalse(gate.privacyOptionsRequired)
    }

    /// The load-bearing regression test: if a future edit drops or inverts the
    /// `canRequestAds` guard in `AdMobAdService.loadNativeAd()`, this fails.
    /// A blocked request must return nil immediately — never falling through
    /// to the SDK's loader/timeout path (which would take ~`AdConfig.loadTimeout`
    /// seconds), since that's the signal the gate short-circuited rather than
    /// the ad simply failing to fill.
    func testLoadNativeAdReturnsNilImmediatelyWhenConsentRequired() async {
        let gate = FakeConsentGate(canRequestAds: false)
        let service = AdMobAdService(settings: AppSettings(defaults: makeIsolatedDefaults()),
                                     consentGate: gate)

        let start = Date()
        let ad = await service.loadNativeAd()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertNil(ad)
        XCTAssertLessThan(elapsed, 1.0,
                          "blocked-by-consent path must short-circuit, not fall through to the SDK load/timeout")
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ConsentGateTests.\(UUID().uuidString)")!
    }
}
