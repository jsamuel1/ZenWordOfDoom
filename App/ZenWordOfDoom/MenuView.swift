import SwiftUI

/// The home screen. Play descends into level select; secondary buttons reach
/// the bestiary and settings.
struct MenuView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.33, saturation: 0.22, brightness: 0.92),
                    Color(hue: 0.55, saturation: 0.30, brightness: 0.60),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Zen Word")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                    Text("of Doom")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red.opacity(0.85))
                }
                .multilineTextAlignment(.center)
                .shadow(radius: 4)

                Text("Serenity \(store.state.serenity)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

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
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        router.push(.levelSelect)
                    } label: {
                        Label("Select Level", systemImage: "square.grid.2x2.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        router.push(.bestiary)
                    } label: {
                        Label("Bestiary", systemImage: "pawprint.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        router.push(.settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
