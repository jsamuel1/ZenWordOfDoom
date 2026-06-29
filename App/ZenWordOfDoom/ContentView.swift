import SwiftUI
import GameCore

struct ContentView: View {
    @StateObject private var model = GameViewModel()

    var body: some View {
        ZStack {
            ZenDoomBackground(stir: model.stir)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header
                GridView(level: model.level, filledCells: model.filledCells)
                    .frame(maxHeight: 260)
                Spacer(minLength: 0)
                wordRibbon
                WheelView(
                    tiles: model.level.wheel.tiles,
                    selection: model.selection,
                    onTap: { model.tap(tileID: $0) }
                )
                controls
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Zen Word of Doom")
                .font(.title2.weight(.semibold))
            Text(model.isComplete ? "The garden settles…" : model.lastMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .animation(.default, value: model.lastMessage)
        }
    }

    private var wordRibbon: some View {
        Text(model.currentWord.isEmpty ? " " : model.currentWord)
            .font(.system(.title, design: .rounded).weight(.bold))
            .tracking(6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private var controls: some View {
        HStack {
            Button("Clear", role: .destructive) { model.clear() }
                .buttonStyle(.bordered)
            Spacer()
            if !model.bonusWords.isEmpty {
                Text("Bonus: \(model.bonusWords.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Submit") { model.submit() }
                .buttonStyle(.borderedProminent)
                .disabled(model.selection.count < GameEngine.minWordLength)
        }
    }
}

/// Calm → Doom tint driven by the engine's stir value (docs/SPEC.md §6.3).
private struct ZenDoomBackground: View {
    let stir: Double
    var body: some View {
        LinearGradient(
            colors: [
                Color(hue: 0.33 - 0.33 * stir, saturation: 0.25 + 0.4 * stir, brightness: 0.9 - 0.5 * stir),
                Color(hue: 0.55 - 0.5 * stir, saturation: 0.30 + 0.3 * stir, brightness: 0.7 - 0.4 * stir),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(alignment: .center) {
            // Placeholder "hidden creature": an eye that opens as stir rises.
            Circle()
                .fill(.red.opacity(0.12 + 0.5 * stir))
                .frame(width: 120, height: 120)
                .blur(radius: 30)
                .opacity(stir)
        }
        .animation(.easeInOut(duration: 0.6), value: stir)
    }
}

#Preview {
    ContentView()
}
