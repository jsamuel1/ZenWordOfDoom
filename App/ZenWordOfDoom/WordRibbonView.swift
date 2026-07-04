import SwiftUI
import LevelGen

/// A calm ribbon showing the word currently being assembled from the wheel.
///
/// Stateless: it renders one capsule per letter of `word`. When empty it shows
/// a faint placeholder so the layout stays stable. The whole thing is a dumb
/// view driven only by its single `word` parameter.
struct WordRibbonView: View {
    let word: String
    let theme: Theme

    @ScaledMetric(relativeTo: .title2) private var tileSide: CGFloat = 38
    @ScaledMetric(relativeTo: .title2) private var ribbonHeight: CGFloat = 44
    private let spacing: CGFloat = 6
    /// Tiles never shrink below this so letters stay legible even for the
    /// longest buildable word (the wheel's own max size, 9 letters).
    private let minTileSide: CGFloat = 24

    private var letters: [Character] { Array(word) }

    var body: some View {
        GeometryReader { geo in
            Group {
                if letters.isEmpty {
                    placeholder
                } else {
                    let side = fittedTileSide(for: geo.size.width)
                    HStack(spacing: spacing) {
                        ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                            letterTile(letter, side: side)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: ribbonHeight)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: word)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letters.isEmpty ? "No word selected" : "Current word \(word)")
    }

    /// Shrinks tiles so the whole word fits the available width instead of
    /// running off-screen for long words (never grows past `tileSide`).
    private func fittedTileSide(for availableWidth: CGFloat) -> CGFloat {
        guard letters.count > 0 else { return tileSide }
        let totalSpacing = spacing * CGFloat(letters.count - 1)
        let perLetter = (availableWidth - totalSpacing) / CGFloat(letters.count)
        return max(min(tileSide, perLetter), minTileSide)
    }

    private func letterTile(_ letter: Character, side: CGFloat) -> some View {
        Text(String(letter))
            .font(.system(.title2, design: .rounded).weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: side, height: side)
            .parchmentReadout(theme: theme)
    }

    private var placeholder: some View {
        Text("Trace a word")
            .font(.system(.subheadline, design: .rounded))
            .parchmentReadout(theme: theme)
    }
}

#Preview {
    VStack(spacing: 16) {
        WordRibbonView(word: "", theme: .zen)
        WordRibbonView(word: "STONE", theme: .zen)
    }
    .padding()
    .background(Color.black)
}
