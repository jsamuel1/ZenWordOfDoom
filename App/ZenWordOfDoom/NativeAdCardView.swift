import SwiftUI
import UIKit
import GoogleMobileAds

/// The cut-scene ad slot. Tries to load a real native ad (styled to match the
/// house card); falls back to the timed `HouseAdCard` on no-fill/timeout so the
/// breath is never blocked indefinitely. `onComplete` unlocks Continue after
/// the same calm dwell either way.
struct AdSlotView: View {
    let onComplete: () -> Void

    @EnvironmentObject private var adBox: AdServiceBox

    private enum Phase {
        case loading
        case native(NativeAd)
        case house
    }
    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                // Quiet shell while the ad loads; the poem holds the screen.
                ProgressView()
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.black.opacity(0.35))
                    )
                    .task {
                        if let ad = await adBox.service.loadNativeAd() {
                            phase = .native(ad)
                        } else {
                            phase = .house
                        }
                    }
            case .native(let ad):
                NativeAdCard(nativeAd: ad, dwell: 5, onComplete: onComplete)
            case .house:
                HouseAdCard(duration: 5, onComplete: onComplete)
            }
        }
    }
}

/// A real native ad in house-card clothing: translucent dark card, small icon +
/// headline + body + CTA, the mandated "Ad" badge, a dwell countdown, and the
/// quiet remove-ads offer underneath.
struct NativeAdCard: View {
    let nativeAd: NativeAd
    let dwell: TimeInterval
    let onComplete: () -> Void

    @State private var remaining = 0
    @State private var done = false

    var body: some View {
        VStack(spacing: 10) {
            NativeAdViewRepresentable(nativeAd: nativeAd)
                .frame(height: 92)

            HStack {
                RemoveAdsButton()
                    .font(.footnote)
                Spacer()
                if !done {
                    Text("\(remaining)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.35))
        )
        .task {
            remaining = Int(dwell.rounded())
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
            done = true
            onComplete()
        }
        .accessibilityElement(children: .contain)
    }
}

/// UIKit bridge for `NativeAdView`. Asset views are registered with the SDK so
/// taps, impression tracking, and AdChoices behave per AdMob policy; the CTA
/// button has user interaction disabled so the SDK handles the tap itself.
private struct NativeAdViewRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.backgroundColor = .clear

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFill
        icon.layer.cornerRadius = 8
        icon.clipsToBounds = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 40),
            icon.heightAnchor.constraint(equalToConstant: 40),
        ])

        let badge = UILabel()
        badge.text = "Ad"
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = .white.withAlphaComponent(0.8)
        badge.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        badge.layer.borderWidth = 1
        badge.layer.cornerRadius = 3
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 22),
            badge.heightAnchor.constraint(equalToConstant: 14),
        ])

        let headline = UILabel()
        headline.font = .preferredFont(forTextStyle: .subheadline)
        headline.textColor = .white
        headline.numberOfLines = 2

        let body = UILabel()
        body.font = .preferredFont(forTextStyle: .caption1)
        body.textColor = .white.withAlphaComponent(0.7)
        body.numberOfLines = 2

        let cta = UIButton(type: .system)
        cta.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        cta.setTitleColor(.systemGreen, for: .normal)
        cta.isUserInteractionEnabled = false   // the SDK intercepts the tap
        cta.setContentHuggingPriority(.required, for: .horizontal)

        let headlineRow = UIStackView(arrangedSubviews: [badge, headline])
        headlineRow.axis = .horizontal
        headlineRow.spacing = 6
        headlineRow.alignment = .center

        let textColumn = UIStackView(arrangedSubviews: [headlineRow, body])
        textColumn.axis = .vertical
        textColumn.spacing = 2

        let row = UIStackView(arrangedSubviews: [icon, textColumn, cta])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        adView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            row.topAnchor.constraint(equalTo: adView.topAnchor),
            row.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor),
        ])

        adView.iconView = icon
        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta
        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.iconView?.isHidden = nativeAd.icon == nil
        (adView.callToActionView as? UIButton)?
            .setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil
        adView.nativeAd = nativeAd
    }
}
