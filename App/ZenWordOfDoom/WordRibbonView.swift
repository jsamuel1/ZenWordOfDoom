import SwiftUI

/// A calm ribbon showing the word currently being assembled from the wheel.
///
/// Stateless: it renders one capsule per letter of `word`. When empty it shows
/// a faint placeholder so the layout stays stable. The whole thing is a dumb
/// view driven only by its single `word` parameter.
struct WordRibbonView: View {
    let word: String

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
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: word)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letters.isEmpty ? "No word selected" : "Current word \(word)")
    }

    private func letterTile(_ letter: Character) -> some View {
        Text(String(letter))
            .font(.system(.title2, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.85))
            )
            .shadow(radius: 1)
    }

    private var placeholder: some View {
        Text("Trace a word")
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.white.opacity(0.4))
    }
}

#Preview {
    VStack(spacing: 16) {
        WordRibbonView(word: "")
        WordRibbonView(word: "STONE")
    }
    .padding()
    .background(Color.black)
}
