import SwiftUI
import GameCore

/// The Shrine: browse, unlock (with serenity), and equip cosmetics — scene
/// palettes and cut-scene poem sets. The serenity sink that makes the currency
/// worth accumulating; a shop that doesn't feel like a shop.
struct ShrineView: View {
    @EnvironmentObject private var store: GameStore

    @State private var showSerenitySheet = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                ForEach(CosmeticsCatalog.items(of: .palette)) { item in
                    row(item, equippedID: store.state.equippedPalette)
                }
            } header: {
                Text("Scene Palettes")
            } footer: {
                Text("Recolor the garden — and what stirs within it.")
            }

            Section {
                ForEach(CosmeticsCatalog.items(of: .poemSet)) { item in
                    row(item, equippedID: store.state.equippedPoemSet)
                }
            } header: {
                Text("Poem Sets")
            } footer: {
                Text("New verses for the breaths between levels.")
            }

            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Shrine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSerenitySheet = true
                } label: {
                    Label("Serenity \(store.state.serenity)", systemImage: "leaf.fill")
                        .font(.subheadline.weight(.medium))
                }
                .accessibilityHint("Get more serenity")
            }
        }
        .sheet(isPresented: $showSerenitySheet) {
            SerenitySheetView()
        }
    }

    private func row(_ item: Cosmetic, equippedID: String?) -> some View {
        let owned = store.state.ownedCosmetics.contains(item.id)
        let equipped = equippedID == item.id
        return Button {
            tap(item, owned: owned, equipped: equipped)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.body.weight(.semibold))
                    Text(item.flavor).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if equipped {
                    Label("Equipped", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                } else if owned {
                    Text("Equip").font(.subheadline).foregroundStyle(.tint)
                } else {
                    Label("\(item.cost)", systemImage: "leaf.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(store.state.serenity >= item.cost ? .primary : .secondary)
                }
            }
        }
        .accessibilityLabel(accessibilityText(item, owned: owned, equipped: equipped))
    }

    private func tap(_ item: Cosmetic, owned: Bool, equipped: Bool) {
        message = nil
        if equipped {
            equip(item, id: nil)                      // tap again to unequip
        } else if owned {
            equip(item, id: item.id)
        } else if store.unlockCosmetic(id: item.id, cost: item.cost) {
            equip(item, id: item.id)                  // unlock includes equipping
            message = "\(item.name) joins the shrine."
        } else {
            message = "Not enough serenity — tap the leaf above for more."
        }
    }

    private func equip(_ item: Cosmetic, id: String?) {
        switch item.kind {
        case .palette: store.equipPalette(id)
        case .poemSet: store.equipPoemSet(id)
        }
    }

    private func accessibilityText(_ item: Cosmetic, owned: Bool, equipped: Bool) -> String {
        if equipped { return "\(item.name), equipped. Tap to unequip." }
        if owned { return "\(item.name), owned. Tap to equip." }
        return "\(item.name), costs \(item.cost) serenity."
    }
}
