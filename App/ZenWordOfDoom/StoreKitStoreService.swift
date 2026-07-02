import Foundation
import StoreKit
import GameCore

/// StoreKit 2 storefront. Loads products, runs purchases with on-device signed
/// verification (no backend), listens for out-of-band updates (Ask to Buy
/// completions, refunds, restores), and reports deliveries through closures so
/// `GameStore` stays the single owner of persisted state.
@MainActor
final class StoreKitStoreService: ObservableObject, StoreService {
    /// Live premium entitlement (also mirrored into SaveState via the closure).
    @Published private(set) var isPremium: Bool = false
    /// Loaded products keyed by product id; empty until the store responds.
    @Published private(set) var productsByID: [String: Product] = [:]

    /// Premium entitlement changed (grant or refund-revocation).
    private let onEntitlementChange: (Bool) -> Void
    /// A verified consumable finished delivering: credit it (dedupe inside).
    private let onConsumable: (StoreItem, UInt64) -> Void

    private var updatesTask: Task<Void, Never>?

    init(onEntitlementChange: @escaping (Bool) -> Void,
         onConsumable: @escaping (StoreItem, UInt64) -> Void) {
        self.onEntitlementChange = onEntitlementChange
        self.onConsumable = onConsumable

        // Out-of-band transactions: Ask to Buy approvals, refunds, purchases
        // completed on another device, replays of unfinished transactions.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self, case .verified(let tx) = update else { continue }
                self.deliver(tx)
                await tx.finish()
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: StoreService

    func displayPrice(for item: StoreItem) -> String? {
        productsByID[item.rawValue]?.displayPrice
    }

    func purchase(_ item: StoreItem) async -> PurchaseOutcome {
        guard let product = productsByID[item.rawValue] else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let tx) = verification else { return .failed }
                deliver(tx)
                await tx.finish()
                return .success(transactionID: UInt64(tx.id))
            case .pending:
                return .pending      // Ask to Buy: arrives later via updates
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: Internals

    private func loadProducts() async {
        let ids = StoreItem.allCases.map(\.rawValue)
        guard let products = try? await Product.products(for: ids) else { return }
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    private func refreshEntitlements() async {
        var premium = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let tx) = entitlement else { continue }
            if tx.productID == StoreItem.premiumRemoveAds.rawValue,
               tx.revocationDate == nil {
                premium = true
            }
        }
        setPremium(premium)
    }

    private func deliver(_ tx: Transaction) {
        guard let item = StoreItem(rawValue: tx.productID) else { return }
        if item == .premiumRemoveAds {
            setPremium(tx.revocationDate == nil)
        } else {
            onConsumable(item, UInt64(tx.id))
        }
    }

    private func setPremium(_ on: Bool) {
        guard isPremium != on else { return }
        isPremium = on
        onEntitlementChange(on)
    }
}
