import SwiftUI
import GameCore
import LevelGen

/// Loads the `Level` for a given id asynchronously via `LevelService`, showing a
/// themed loader until it resolves, then renders the play UI in `GamePlayView`.
struct GameContainerView: View {
    let levelID: String

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var levelService: LevelService
    @EnvironmentObject private var soundBox: SoundEngineBox

    @State private var loaded: Level?
    @State private var failed = false

    var body: some View {
        Group {
            if let level = loaded {
                GamePlayView(level: level, settings: settings, store: store,
                             soundEngine: soundBox.engine,
                             mood: levelService.theme(forID: level.id) == .doom ? .doom : .zen)
            } else if failed {
                VStack(spacing: 16) {
                    Text("Couldn't compose this level")
                        .font(.headline)
                    Button("Retry") { failed = false; Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                LoadingView(theme: levelService.theme(forID: levelID))
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard loaded == nil else { return }
        if let level = await levelService.level(id: levelID) { loaded = level }
        else { failed = true }
    }
}

/// The full play screen for one loaded level. Builds the `GameViewModel`, composes
/// the procedural background, grid, word ribbon, wheel, and HUD, wires voice input,
/// and on completion pushes the cut scene route.
struct GamePlayView: View {
    let level: Level

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var levelService: LevelService

    @StateObject private var model: GameViewModel
    @StateObject private var voice = VoiceInput()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pack banner shown briefly when entering a pack's first level.
    @State private var packBanner: Pack?
    /// Serenity top-up sheet, reachable only via the failed-hint message.
    @State private var showSerenitySheet = false
    /// Gates the scorecard: stays false during the held creature-reveal beat so
    /// the reveal isn't covered, then flips true once the hold completes.
    @State private var showClear = false
    /// True while a word-trace drag is in flight on the wheel. Disables the
    /// enclosing ScrollView for the drag's duration so the scroll pan can't
    /// steal the trace (belt-and-braces alongside the wheel's
    /// .highPriorityGesture).
    @State private var wheelDragging = false

    /// Shared audio engine, retained for start/stop/enable over the level's life.
    private let soundEngine: any SoundEngine

    init(level: Level, settings: AppSettings, store: GameStore,
         soundEngine: any SoundEngine, mood: MusicMood) {
        self.level = level
        self.soundEngine = soundEngine
        _model = StateObject(wrappedValue: GameViewModel(
            level: level,
            validator: SystemDictionary(),
            settings: settings,
            store: store,
            soundEngine: soundEngine,
            mood: mood
        ))
    }

    var body: some View {
        ZStack {
            // GeometryReader gives the scroll content a minHeight equal to the
            // viewport, so the Spacer inside the VStack resolves exactly as it
            // did pre-ScrollView at standard type sizes; at accessibility
            // sizes the content exceeds the viewport and scrolls instead.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        HUDView(
                            score: model.score,
                            scoreVoided: model.doomExpired,
                            serenity: model.serenity,
                            hintCost: model.hintCost,
                            timeRemaining: model.timeRemaining,
                            isListening: voice.isListening,
                            voiceEnabled: settings.voiceEnabled,
                            onHint: {
                                Haptics.reveal()
                                model.useHintRevealCell()
                            },
                            onMicStart: { startListening() },
                            onMicStop: { voice.stop() }
                        )

                        Text(model.lastMessage)
                            .font(.subheadline)
                            .foregroundStyle(model.wantsSerenityOffer ? .primary : .secondary)
                            .underline(model.wantsSerenityOffer)
                            .animation(.default, value: model.lastMessage)
                            .accessibilityLiveRegion()
                            .onTapGesture {
                                guard model.wantsSerenityOffer else { return }
                                showSerenitySheet = true
                            }
                            .accessibilityAddTraits(model.wantsSerenityOffer ? .isButton : [])

                        GridView(
                            level: model.level,
                            filledCells: model.filledCells,
                            solvedSlotIDs: model.solvedSlotIDs
                        )
                        .frame(maxHeight: gridMaxHeight(viewport: proxy.size.height))

                        Spacer(minLength: 0)

                        FoundWordsTray(progress: model.progressLabel, bonusWords: model.bonusWords)

                        WordRibbonView(word: model.currentWord)

                        WheelView(
                            tiles: model.level.wheel.tiles,
                            displayOrder: model.displayOrder,
                            selection: model.selection,
                            onTap: { id in
                                Haptics.tap()
                                model.tap(tileID: id)
                            },
                            onSwipeBegin: { id in
                                Haptics.tap()
                                wheelDragging = true
                                model.swipeBegin(tileID: id)
                            },
                            onSwipeExtend: { id in model.swipeExtend(tileID: id) },
                            onSwipeEnd: {
                                wheelDragging = false
                                model.swipeEnd()
                            }
                        )

                        controls
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    // Task 4 hooks here
                    .opacity(model.isComplete ? 0 : 1)
                    .animation(.easeOut(duration: 0.5), value: model.isComplete)
                    .allowsHitTesting(!model.isComplete)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Frozen chrome must not scroll behind the clear overlay, and
                // an in-flight wheel trace must never turn into a scroll.
                .scrollDisabled(wheelDragging || model.isComplete)
            }
        }
        // The scene is a .background — NOT a ZStack child — so its
        // scaledToFill art can never inflate the layout proposal the chrome
        // receives. (As a ZStack sibling, the oversized fill made the chrome
        // lay out wider than the screen, pushing the HUD edges and the
        // Clear/Submit row off-screen at every type size.) It stays
        // full-screen, outside the scroll, and never scrolls.
        .background {
            SceneRevealView(
                sceneID: model.level.sceneID,
                creatureID: model.level.creatureID,
                theme: levelService.theme(forID: level.id),
                stir: model.stir,
                reducedDoom: settings.reducedDoom,
                reducedMotion: reduceMotion,
                paletteID: store.state.equippedPalette
            )
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if let pack = packBanner {
                PackBannerView(pack: pack)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if showClear, let summary = model.clearSummary {
                LevelClearView(summary: summary, reducedMotion: reduceMotion) {
                    router.push(.cutScene(afterLevelID: level.id, sceneID: level.sceneID, creatureID: level.creatureID))
                }
                .padding(.horizontal, 40)
                .transition(.opacity)
            }
        }
        .overlay {
            if model.showDoomOverlay {
                DoomExpiredOverlay(reducedDoom: settings.reducedDoom) {
                    model.continueWithoutPoints()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(packTitle)
        .onAppear {
            model.startTimerIfDoom()
            showPackBannerIfNeeded()
            soundEngine.setEnabled(settings.soundEnabled)
            soundEngine.start()
        }
        .onDisappear {
            model.invalidate()
            voice.stop()
            soundEngine.stop()
        }
        .onChange(of: settings.soundEnabled) { _, on in
            soundEngine.setEnabled(on)
        }
        // The doom overlay blocks all play input; the mic must not keep
        // listening (and submitting words) underneath it.
        .onChange(of: model.showDoomOverlay) { _, shown in
            if shown { voice.stop() }
        }
        .sheet(isPresented: $showSerenitySheet) {
            SerenitySheetView()
        }
        .task(id: model.isComplete) {
            // `!showClear` guards re-entrancy: .task(id:) restarts when the view
            // reappears (e.g. swiping back from the cut scene) with isComplete
            // still true, and the celebration must not replay.
            guard model.isComplete, !showClear else { return }
            Haptics.success()
            voice.stop()
            // Hold on the fully revealed creature (stir is 1) with the chrome
            // faded, so the payoff is actually seen; then bring in the scorecard.
            let hold: UInt64 = reduceMotion ? 800_000_000 : 2_200_000_000
            guard (try? await Task.sleep(nanoseconds: hold)) != nil else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showClear = true
            }
        }
    }

    /// Height available to the grid: the viewport minus the rest of the
    /// chrome (HUD + message + tray + ribbon + 240pt wheel + controls +
    /// spacing ≈ 610pt at standard Dynamic Type), capped at the design's
    /// 380pt. Pre-ScrollView, the fixed-height proposal squeezed the grid
    /// to this leftover automatically; inside a ScrollView the height
    /// proposal is unbounded, so without this cap the grid takes its full
    /// ideal and pushes the content past the viewport at default sizes.
    /// Floored at 140pt so the grid stays legible when larger type eats the
    /// leftover — at accessibility sizes the ScrollView provides the room
    /// instead.
    private func gridMaxHeight(viewport: CGFloat) -> CGFloat {
        min(380, max(140, viewport - 610))
    }

    private var packTitle: String {
        if let pack = levelService.pack(forID: level.id) { return pack.name }
        let theme = levelService.theme(forID: level.id).rawValue.capitalized
        let band = level.band.rawValue.capitalized
        return "\(theme) · \(band)"
    }

    private var controls: some View {
        HStack {
            Button("Clear", role: .destructive) { model.clear() }
                .buttonStyle(.bordered)

            Spacer()

            Button {
                Haptics.tap()
                model.shuffle()
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Shuffle letters")

            Spacer()

            Button("Submit") {
                Haptics.tap()
                model.submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selection.count < GameEngine.minWordLength)
        }
    }

    private func showPackBannerIfNeeded() {
        guard packBanner == nil, levelService.isPackStart(level.id),
              let pack = levelService.pack(forID: level.id) else { return }
        withAnimation(.easeOut(duration: 0.4)) { packBanner = pack }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeIn(duration: 0.5)) { packBanner = nil }
        }
    }

    private func startListening() {
        Task {
            let ok = await voice.requestAuthorization()
            guard ok else {
                return
            }
            voice.start(onResult: { transcript in
                model.submitSpoken(transcript)
            })
        }
    }
}

private struct LoadingView: View {
    let theme: Theme
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(theme == .zen ? "Composing the garden…" : "Stirring the doom…")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private extension View {
    /// Marks dynamic status text as a live region for VoiceOver where available.
    @ViewBuilder
    func accessibilityLiveRegion() -> some View {
        self.accessibilityAddTraits(.updatesFrequently)
    }
}

/// Full-screen pause when the doom timer expires: dims the scene (gentler with
/// Reduced Doom), announces the forfeit, and lets the player continue unscored.
private struct DoomExpiredOverlay: View {
    let reducedDoom: Bool
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(reducedDoom ? 0.35 : 0.55)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("The doom has claimed this hour")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("The words remain. The points do not.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Continue without points", action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial))
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}
