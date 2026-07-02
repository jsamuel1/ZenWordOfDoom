import Foundation

/// Everything purchasable, keyed by App Store product id.
public enum StoreItem: String, CaseIterable, Sendable {
    case premiumRemoveAds = "wtf.sauhsoj.zenwordofdoom.premium"
    case serenitySmall = "wtf.sauhsoj.zenwordofdoom.serenity.small"
    case serenityMedium = "wtf.sauhsoj.zenwordofdoom.serenity.medium"
    case serenityLarge = "wtf.sauhsoj.zenwordofdoom.serenity.large"

    /// Serenity credited by a consumable, or nil for the non-consumable premium.
    public var serenityAmount: Int? {
        switch self {
        case .premiumRemoveAds: return nil
        case .serenitySmall:    return 10
        case .serenityMedium:   return 25
        case .serenityLarge:    return 50
        }
    }

    public var isConsumable: Bool { serenityAmount != nil }
}

/// Result of a purchase attempt, backend-agnostic.
public enum PurchaseOutcome: Equatable, Sendable {
    /// Verified and delivered. `transactionID` lets the caller dedupe replays.
    case success(transactionID: UInt64)
    /// Deferred (e.g. Ask to Buy); delivery arrives later via the updates path.
    case pending
    case cancelled
    case failed
}

/// Storefront seam. The app provides a StoreKit 2 implementation;
/// `MockStoreService`-style doubles drive tests and previews.
@MainActor
public protocol StoreService: AnyObject {
    /// Live entitlement to the remove-ads premium.
    var isPremium: Bool { get }
    /// Localized display price ("$4.99"), or nil until products have loaded.
    func displayPrice(for item: StoreItem) -> String?
    func purchase(_ item: StoreItem) async -> PurchaseOutcome
    /// Sync past purchases (new device / reinstall).
    func restore() async
}

/// When free players see a cut-scene ad. Pack 1 (the first
/// `adFreeLevelCount` levels) is an ad-free grace period — including the
/// breath after the pack-1 capstone, so the signature-creature beat stays
/// clean. Premium removes ads entirely. Ads never appear anywhere else.
public enum AdPolicy {
    /// Number of leading levels (play orders 0..<count) whose following cut
    /// scenes stay ad-free.
    public static let adFreeLevelCount = 10

    /// Whether the cut scene following the level at `order` carries an ad.
    public static func shouldShowAd(afterLevelOrder order: Int, isPremium: Bool) -> Bool {
        !isPremium && order >= adFreeLevelCount
    }
}
