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

    private var letters: [Character] { Array(word) }

    var body: some View {
        Group {
            if letters.isEmpty {
                placeholder
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                        letterTile(letter)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: ribbonHeight)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: word)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letters.isEmpty ? "No word selected" : "Current word \(word)")
    }

    private func letterTile(_ letter: Character) -> some View {
        Text(String(letter))
            .font(.system(.title2, design: .rounded).weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: tileSide, height: tileSide)
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
