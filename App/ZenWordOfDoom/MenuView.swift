import SwiftUI
import LevelGen

/// The home screen. Play descends into level select; secondary buttons reach
/// the bestiary and settings.
struct MenuView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: GameStore

    @State private var showSerenitySheet = false

    /// Hero illustrations depicting the game's "Zen meets Doom" premise. One is
    /// picked per launch (stable for the session) as the title screen backdrop.
    /// `static` so the choice survives MenuView being re-created on every
    /// return to the menu, instead of re-rolling per appearance.
    static let titleArt = [
        "monk-in-ruins", "doom-marine-shrine", "garden-in-the-ruins",
        "monk-on-skulls", "mandala-and-void", "elder-and-volcano",
    ]
    private static let backdrop = titleArt.randomElement() ?? "monk-in-ruins"

    var body: some View {
        ZStack {
            // GeometryReader gives the scroll content a minHeight equal to
            // the viewport, so the Spacers resolve exactly as they did
            // before the ScrollView existed at standard type sizes; at
            // accessibility sizes the content exceeds the viewport and
            // scrolls instead.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()

                        // Localized scrim (audit 3.4) — not full-screen — so
                        // the title/serenity/daily block holds contrast over
                        // whichever hero photo was picked for this launch.
                        // `.blur` + negative padding softens the scrim's
                        // edge instead of a hard-edged box.
                        VStack(spacing: 24) {
                            // Title and serenity readout sit tight together
                            // as one masthead unit.
                            VStack(spacing: 4) {
                                // Negative spacing compensates for the brand
                                // faces' huge built-in vertical metrics: at
                                // 44pt Buda leaves ~15pt of empty air below
                                // its baseline and Grenze Gotisch ~20pt above
                                // its caps, so even spacing 0 reads as a
                                // ~35pt gap. -26 nets a ~9pt visual gap; the
                                // metric air scales up with Dynamic Type
                                // while this constant doesn't, so the lines
                                // can never overlap.
                                VStack(spacing: -26) {
                                    Text("Zen Word")
                                        .font(BrandFont.zen(size: 44))
                                        .foregroundStyle(.white)
                                    Text("of Doom")
                                        .font(BrandFont.doom(size: 44))
                                        .foregroundStyle(.red.opacity(0.85))
                                }
                                .multilineTextAlignment(.center)
                                .shadow(radius: 4)

                                Button {
                                    showSerenitySheet = true
                                } label: {
                                    Label("Serenity \(store.state.serenity)", systemImage: "leaf.fill")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        // Button-shape affordance (audit 6.3):
                                        // this is a plain-styled tappable row,
                                        // not inside a List, so it gets no
                                        // platform row affordance for free.
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Get more serenity")
                            }

                            dailyCard
                        }
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.black.opacity(0.45), .black.opacity(0.25)],
                                startPoint: .top, endPoint: .bottom
                            )
                            .blur(radius: 8)
                            .padding(-12)
                        )

                        // No Spacer here: the daily card and the Play button
                        // belong to one action cluster, so they keep a fixed
                        // 32pt gap. Leftover height goes to the outer Spacers,
                        // which center the cluster instead of stretching it.
                        VStack(spacing: 16) {
                            Button {
                                // Drop straight into the next level to play; if every
                                // level is cleared there's nothing new, so show the list.
                                if let next = store.nextUnclearedLevelID {
                                    router.push(.game(levelID: next))
                                } else {
                                    router.push(.levelSelect)
                                }
                            } label: {
                                Label("Play", systemImage: "leaf.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))

                            // One shared parchment piece for the secondary
                            // destinations — a single mat + accent outline
                            // around all five rows, not five separately
                            // bordered buttons.
                            VStack(spacing: 0) {
                                menuRow("Select Level", systemImage: "square.grid.2x2.fill") {
                                    router.push(.levelSelect)
                                }
                                rowDivider
                                menuRow("Bestiary", systemImage: "pawprint.fill") {
                                    router.push(.bestiary)
                                }
                                rowDivider
                                menuRow("Shrine", systemImage: "sparkles") {
                                    router.push(.shrine)
                                }
                                rowDivider
                                menuRow("Stats", systemImage: "chart.bar.fill") {
                                    router.push(.stats)
                                }
                                rowDivider
                                menuRow("Settings", systemImage: "gearshape.fill") {
                                    router.push(.settings)
                                }
                            }
                            .parchmentPanel(theme: .zen)
                        }
                        .padding(.horizontal, 40)

                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        // Hero image + gradient live in .background — NOT as ZStack children —
        // so the scaledToFill image can never inflate the layout proposal the
        // menu content receives. (As a sibling, the oversized fill made the
        // buttons lay out wider than the screen.) Full-bleed, outside the
        // scroll, never scrolls.
        .background {
            ZStack {
                Image(Self.backdrop)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [
                        Color(hue: 0.33, saturation: 0.22, brightness: 0.92).opacity(0.35),
                        Color(hue: 0.55, saturation: 0.30, brightness: 0.45).opacity(0.75),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSerenitySheet) {
            SerenitySheetView()
        }
    }

    private func menuRow(
        _ title: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ParchmentRowButtonStyle(theme: .zen))
    }

    /// Hairline between panel rows — low-opacity ink so it reads as scoring
    /// on the parchment rather than a system divider.
    private var rowDivider: some View {
        Rectangle()
            .fill(AccessibilityPalette.parchmentInk(for: .zen).opacity(0.15))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private var dailyCard: some View {
        let dailyID = DailyPuzzle.id(for: Date())
        let cleared = store.isCleared(dailyID)
        let streak = store.state.stats.currentStreak
        return Button {
            router.push(.game(levelID: dailyID))
        } label: {
            // A single trailing play glyph is the only ornament — flanking
            // icons on both sides squeezed the title into wrapping.
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Play Today’s Doom Word")
                        // One notch below .headline so the title holds a
                        // single line inside the parchment at common widths
                        // and type sizes.
                        .font(.subheadline.weight(.semibold))
                    Text(cleared ? "Cleared — the garden rests" : "One puzzle. Every soul. Every day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if streak > 0 {
                        Label("\(streak) day streak", systemImage: "flame.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))
        .padding(.horizontal, 40)
    }
}
