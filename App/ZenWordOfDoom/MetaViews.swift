import SwiftUI
import LevelGen

/// Compact progress + collected bonus words, shown above the wheel so the player
/// can see how many words remain and admire what they've found (spec workstream C).
struct FoundWordsTray: View {
    let progress: String
    let bonusWords: [String]

    var body: some View {
        VStack(spacing: 6) {
            Text(progress)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if !bonusWords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // Most-recent first so a new find slides in at the front.
                        // Bonus words are unique (deduped in the engine), so the
                        // word itself is a stable identity.
                        ForEach(bonusWords.reversed(), id: \.self) { word in
                            Text(word)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .a11yCardBackground(cornerRadius: .infinity)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress). \(bonusWords.count) bonus words found.")
    }
}

/// A brief banner announcing a new pack on entering its first level.
struct PackBannerView: View {
    let pack: Pack
    let theme: Theme

    var body: some View {
        VStack(spacing: 4) {
            Text(pack.name)
                .font(BrandFont.themed(theme, size: 20, relativeTo: .title3))
            if !pack.flavor.isEmpty {
                Text(pack.flavor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .a11yCardBackground(cornerRadius: 16)
        .shadow(radius: 8, y: 4)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pack: \(pack.name). \(pack.flavor)")
    }
}
