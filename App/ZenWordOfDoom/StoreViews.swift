import SwiftUI
import GameCore

/// Small top-up sheet for serenity consumables. Reached from the tappable
/// serenity counters and the failed-hint nudge — never a popup.
struct SerenitySheetView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var storeService: StoreKitStoreService
    @Environment(\.dismiss) private var dismiss

    @State private var purchasing: StoreItem?
    @State private var message: String?

    private let packs: [StoreItem] = [.serenitySmall, .serenityMedium, .serenityLarge]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(packs, id: \.rawValue) { pack in
                        row(for: pack)
                    }
                } header: {
                    Label("Serenity \(store.state.serenity)", systemImage: "leaf.fill")
                } footer: {
                    Text("Serenity is also earned by playing — packs are never required.")
                }

                if let message {
                    Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Serenity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func row(for pack: StoreItem) -> some View {
        HStack {
            Label("\(pack.serenityAmount ?? 0)", systemImage: "leaf.fill")
                .font(.body.weight(.semibold))
            Spacer()
            Button {
                buy(pack)
            } label: {
                // 44pt touch-target floor (audit 4.1) on the label content.
                Group {
                    if purchasing == pack {
                        ProgressView()
                    } else {
                        Text(storeService.displayPrice(for: pack) ?? "—")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchasing != nil || storeService.displayPrice(for: pack) == nil)
        }
        .accessibilityElement(children: .combine)
    }

    private func buy(_ pack: StoreItem) {
        purchasing = pack
        message = nil
        Task {
            let outcome = await storeService.purchase(pack)
            purchasing = nil
            switch outcome {
            case .success:   message = "Serenity added. Breathe easy."
            case .pending:   message = "Waiting for approval…"
            case .cancelled: break
            case .failed:    message = "The store didn't respond. Try again later."
            }
        }
    }
}

/// The remove-ads offer: a single quiet row usable from Settings and the
/// cut-scene ad card. Shows the live price; disappears once premium.
struct RemoveAdsButton: View {
    @EnvironmentObject private var storeService: StoreKitStoreService

    @State private var purchasing = false
    @State private var message: String?

    var body: some View {
        if storeService.isPremium {
            Label("Ads removed — thank you", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    buy()
                } label: {
                    HStack {
                        Label("Remove Ads", systemImage: "sparkles")
                        Spacer()
                        if purchasing {
                            ProgressView()
                        } else {
                            Text(storeService.displayPrice(for: .premiumRemoveAds) ?? "—")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .disabled(purchasing || storeService.displayPrice(for: .premiumRemoveAds) == nil)

                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func buy() {
        purchasing = true
        message = nil
        Task {
            let outcome = await storeService.purchase(.premiumRemoveAds)
            purchasing = false
            switch outcome {
            case .success:   message = nil
            case .pending:   message = "Waiting for approval…"
            case .cancelled: break
            case .failed:    message = "The store didn't respond. Try again later."
            }
        }
    }
}

/// Placeholder ad slot for the cut scene: a quiet card that "plays" for a fixed
/// duration, then calls `onComplete` so Continue can appear. Stands in for the
/// real ad SDK behind the same gating flow (spec: never trapped — the timer IS
/// the no-fill fallback). Carries the unobtrusive remove-ads offer.
struct HouseAdCard: View {
    let duration: TimeInterval
    let onComplete: () -> Void

    @State private var remaining: Int = 0
    @State private var done = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.circle")
                    .foregroundStyle(.secondary)
                Text(done ? "Thanks for supporting the garden"
                          : "A brief pause supports the garden…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                if !done {
                    Text("\(remaining)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            RemoveAdsButton()
                .font(.footnote)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.35))
        )
        .task {
            remaining = Int(duration.rounded())
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remaining -= 1
            }
            done = true
            onComplete()
        }
        .accessibilityElement(children: .combine)
    }
}
