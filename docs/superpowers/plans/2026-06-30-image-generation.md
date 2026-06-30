# On-Device Image Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Generate themed bestiary portraits and cut-scene art on-device with Image Playground, cached per id, with the existing procedural rendering as a universal fallback.

**Architecture:** A `SceneVisualProvider` seam + disk cache + a `GeneratedImageView` SwiftUI primitive are built **first** (with a no-op provider, so the app is unchanged and always shows the procedural fallback). The `ImageCreator`-backed provider plugs in behind the seam; if the API is unavailable it degrades to the fallback with no integration rework. Prompt strings are pure data in `LevelGen`.

**Tech Stack:** Swift 5.9, SwiftUI, `ImagePlayground` framework (`ImageCreator`), the `LevelGen` package.

**Spec:** [`2026-06-30-on-device-image-generation-design.md`](../specs/2026-06-30-on-device-image-generation-design.md).

**Verification:**
- LevelGen task (1): `DEVELOPER_DIR=/Users/jsamuel/Downloads/Xcode-beta.app/Contents/Developer swift test`
- App tasks (2–5): `xcodegen generate` then
  ```
  DEVELOPER_DIR=/Users/jsamuel/Downloads/Xcode-beta.app/Contents/Developer \
    xcodebuild -scheme ZenWordOfDoom \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath .build/xcode build CODE_SIGNING_ALLOWED=NO | tail -20
  ```
  Expect `** BUILD SUCCEEDED **`. The simulator can't generate images, so the **procedural fallback path is what runs** — that's expected and correct.

---

## Task 1: VisualPrompts (pure, in LevelGen)

**Files:** Create `Sources/LevelGen/VisualPrompts.swift`; Test `Tests/LevelGenTests/VisualPromptsTests.swift`.

- [ ] **Step 1 — failing test:**
```swift
import XCTest
import GameCore
@testable import LevelGen

final class VisualPromptsTests: XCTestCase {
    func testEverySlugHasNonEmptyPrompt() {
        let pools = ThemePools.zenDoom
        for theme in Theme.allCases {
            for id in pools.scenes[theme] ?? [] {
                XCTAssertFalse(VisualPrompts.prompt(forSceneID: id, theme: theme).isEmpty, "scene \(id)")
            }
            for id in pools.creatures[theme] ?? [] {
                XCTAssertFalse(VisualPrompts.prompt(forCreatureID: id, theme: theme).isEmpty, "creature \(id)")
            }
        }
    }
    func testPromptsAvoidNamedIP() {
        let banned = ["cthulhu", "doomguy", "buffy", "doom guy"]
        let pools = ThemePools.zenDoom
        for theme in Theme.allCases {
            for id in (pools.scenes[theme] ?? []) + (pools.creatures[theme] ?? []) {
                let p = (VisualPrompts.prompt(forSceneID: id, theme: theme)
                         + " " + VisualPrompts.prompt(forCreatureID: id, theme: theme)).lowercased()
                for token in banned { XCTAssertFalse(p.contains(token), "\(id) leaks \(token)") }
            }
        }
    }
    func testUnknownSlugFallsBackByTheme() {
        XCTAssertFalse(VisualPrompts.prompt(forSceneID: "totally-unknown", theme: .doom).isEmpty)
    }
    func testPromptVersionIsPositive() { XCTAssertGreaterThan(VisualPrompts.promptVersion, 0) }
}
```
- [ ] **Step 2 — run, watch fail.**
- [ ] **Step 3 — implement `VisualPrompts.swift`:**
```swift
import GameCore

/// IP-free, guardrail-safe image prompts for the curated scene/creature slugs.
/// Bump `promptVersion` whenever prompt text changes (invalidates the cache).
public enum VisualPrompts {
    public static let promptVersion = 1

    public static func prompt(forSceneID id: String, theme: Theme) -> String {
        scenePrompts[id] ?? genericScene(theme)
    }
    public static func prompt(forCreatureID id: String, theme: Theme) -> String {
        creaturePrompts[id] ?? genericCreature(theme)
    }

    private static func genericScene(_ t: Theme) -> String {
        t == .zen
        ? "a serene minimalist nature scene, soft pastel light, calm illustration"
        : "an ancient ruined place at night, faint eerie glow, ominous stylized illustration"
    }
    private static func genericCreature(_ t: Theme) -> String {
        t == .zen
        ? "a gentle glowing spirit guardian, soft watercolor, calm"
        : "a mysterious shadowy creature with glowing eyes, deep teal and violet, stylized, ominous but not gory"
    }

    private static let scenePrompts: [String: String] = [
        "still-pond": "a calm koi pond at dawn, soft mist, pastel illustration",
        "moss-garden": "a quiet moss garden with smooth stones, gentle green light, calm illustration",
        "bamboo-grove": "a tranquil bamboo grove, soft sunbeams, serene illustration",
        "misty-peak": "a distant mountain peak above soft clouds, pale dawn, calm illustration",
        "lantern-path": "a winding stone path lit by paper lanterns at dusk, peaceful illustration",
        "sand-ripples": "a raked zen sand garden in concentric ripples, soft shadows, calm illustration",
        "willow-bank": "a willow tree over a still river bank, gentle breeze, serene illustration",
        "sunken-crypt": "an ancient overgrown stone crypt at night, faint green glow, ominous stylized illustration",
        "black-abyss": "a yawning dark chasm with faint glowing motes, deep blue-black, ominous stylized illustration",
        "thorn-hollow": "a twisted thorn thicket under a blood-orange moon, eerie, stylized illustration",
        "ruined-shrine": "a crumbling forgotten shrine wreathed in fog, cold light, ominous stylized illustration",
        "ashen-moor": "a bleak ash-grey moor under a bruised sky, lonely, ominous stylized illustration",
        "drowned-temple": "a half-submerged stone temple in dark water, teal gloom, ominous stylized illustration",
        "ember-catacomb": "a shadowy catacomb lit by dim embers, deep red glow, ominous stylized illustration",
    ]
    private static let creaturePrompts: [String: String] = [
        "koi-spirit": "a serene glowing koi spirit, soft watercolor, calm",
        "stone-guardian": "a mossy stone guardian statue with kind eyes, soft light, calm illustration",
        "crane-shade": "a graceful pale crane silhouette in mist, serene illustration",
        "lotus-wisp": "a glowing lotus-shaped wisp of light, soft pastels, calm",
        "moss-golem": "a gentle round golem of moss and stone, soft green, calm illustration",
        "paper-fox": "a delicate origami fox glowing softly, calm pastel illustration",
        "deep-tentacle": "a coiling deep-sea tentacle creature, teal and violet, eerie bioluminescent glow, stylized",
        "gloom-eye": "a single large floating eye sigil ringed with runes, sickly green glow, stylized, ominous",
        "bone-wraith": "a tattered hooded wraith of pale bone and shadow, cold blue glow, stylized, ominous not gory",
        "mask-fiend": "an ancient cracked ritual mask with an eerie green glow, stylized, ominous",
        "thorn-revenant": "a figure woven from black thorns and fog, glowing eyes, stylized, ominous not gory",
        "ash-maw": "a shadowy maw of drifting ash and embers, deep red glow, abstract, stylized, ominous",
    ]
}
```
- [ ] **Step 4 — run, watch pass; full `swift test` green.**
- [ ] **Step 5 — commit:** `feat(levelgen): IP-free image prompts for scene/creature slugs`.

---

## Task 2: Visual seam, cache, and GeneratedImageView (app; no-op provider)

**Files:** Create `App/ZenWordOfDoom/SceneVisualProvider.swift`, `App/ZenWordOfDoom/VisualCache.swift`, `App/ZenWordOfDoom/GeneratedImageView.swift`; modify `ZenWordOfDoomApp.swift` (inject provider).

Build the seam + cache + view with a provider that always returns `nil`, so the app compiles and shows the procedural fallback everywhere — unchanged behavior, de-risked foundation.

- [ ] **Step 1 — `SceneVisualProvider.swift`:**
```swift
import CoreGraphics
import LevelGen

enum VisualKind: String { case scene, creature }

struct VisualRequest: Hashable {
    let id: String          // scene or creature slug
    let theme: Theme
    let kind: VisualKind
}

/// Produces a themed image for a request, on-device, or nil if unavailable.
protocol SceneVisualProvider: Sendable {
    func image(for request: VisualRequest, maxPixel: Int) async -> CGImage?
}

/// Default provider used until/unless Image Playground is wired in; always nil
/// so callers fall back to procedural rendering.
struct UnavailableVisualProvider: SceneVisualProvider {
    func image(for request: VisualRequest, maxPixel: Int) async -> CGImage? { nil }
}
```
- [ ] **Step 2 — `VisualCache.swift`** (disk PNG cache, keyed by id+kind+style+promptVersion):
```swift
import UIKit

/// Disk cache for generated visuals under Caches/visuals/. Disposable.
struct VisualCache {
    static let shared = VisualCache()
    private let dir: URL

    init() {
        let base = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        dir = base.appendingPathComponent("visuals", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func key(for request: VisualRequest, style: String) -> String {
        "\(request.id)-\(request.kind.rawValue)-\(style)-v\(VisualPrompts.promptVersion)"
    }
    private func url(_ key: String) -> URL { dir.appendingPathComponent(key + ".png") }

    func image(forKey key: String) -> CGImage? {
        guard let data = try? Data(contentsOf: url(key)), let img = UIImage(data: data) else { return nil }
        return img.cgImage
    }
    func store(_ cgImage: CGImage, forKey key: String) {
        let img = UIImage(cgImage: cgImage)
        guard let data = img.pngData() else { return }
        try? data.write(to: url(key), options: [.atomic])
    }
}
```
(Add `import LevelGen` where `VisualPrompts` is referenced.)
- [ ] **Step 3 — `GeneratedImageView.swift`:** a view that shows a fallback, then swaps in the generated image when resolved.
```swift
import SwiftUI
import LevelGen

struct GeneratedImageView<Fallback: View>: View {
    let request: VisualRequest
    var maxPixel: Int = 512
    @ViewBuilder let fallback: () -> Fallback

    @EnvironmentObject private var visuals: VisualProviderBox
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
                    .transition(.opacity)
            } else {
                fallback()
            }
        }
        .task(id: request) {
            if let cg = await visuals.provider.image(for: request, maxPixel: maxPixel) {
                withAnimation(.easeIn(duration: 0.4)) { image = cg }
            }
        }
    }
}

/// Environment box so the provider can be swapped without touching call sites.
@MainActor
final class VisualProviderBox: ObservableObject {
    let provider: SceneVisualProvider
    init(provider: SceneVisualProvider) { self.provider = provider }
}
```
- [ ] **Step 4 — inject** in `ZenWordOfDoomApp.swift`: `@StateObject private var visuals = VisualProviderBox(provider: UnavailableVisualProvider())` and `.environmentObject(visuals)` on `ContentView()`. (Task 3 swaps the provider for the Image Playground one.)
- [ ] **Step 5 — build** → BUILD SUCCEEDED (nothing uses `GeneratedImageView` yet; app unchanged).
- [ ] **Step 6 — commit:** `feat(app): SceneVisualProvider seam, disk cache, GeneratedImageView`.

---

## Task 3: ImagePlayground provider

**Files:** Create `App/ZenWordOfDoom/ImagePlaygroundVisualProvider.swift`; modify `ZenWordOfDoomApp.swift` (use it as the default provider).

**FIRST — API probe.** Confirm `import ImagePlayground` and `ImageCreator` compile against the iOS 26.5 SDK (the programmatic API may be de-emphasized). Write the smallest possible file that references `ImageCreator` and build it. **If it does not compile / the type is unavailable, STOP and report BLOCKED** — Task 2's `UnavailableVisualProvider` already ships the graceful fallback, so the feature still works; the engine decision gets revisited. Do NOT force a workaround.

- [ ] **Step 1 — probe** the API surface. The expected shape (verify against the SDK, adapt names if needed):
  `let creator = try await ImageCreator()`; `creator.availableStyles -> [ImagePlaygroundStyle]`; `creator.images(for: [ImagePlaygroundConcept], style: ImagePlaygroundStyle, limit: Int)` returns an `AsyncSequence` whose elements expose `.cgImage`. `ImagePlaygroundConcept.text(String)`.
- [ ] **Step 2 — implement** (adapt to the real API):
```swift
import ImagePlayground
import CoreGraphics
import LevelGen

actor ImagePlaygroundVisualProvider: SceneVisualProvider {
    private var creator: ImageCreator?
    private var unavailable = false

    private func makeCreator() async -> ImageCreator? {
        if let creator { return creator }
        if unavailable { return nil }
        do { let c = try await ImageCreator(); creator = c; return c }
        catch { unavailable = true; return nil }
    }

    func image(for request: VisualRequest, maxPixel: Int) async -> CGImage? {
        guard let creator = await makeCreator() else { return nil }
        let style = creator.availableStyles.first { "\($0)".contains("illustration") }
            ?? creator.availableStyles.first
        guard let style else { return nil }
        let cacheKey = VisualCache.shared.key(for: request, style: "\(style)")
        if let cached = VisualCache.shared.image(forKey: cacheKey) { return cached }

        let prompt = request.kind == .scene
            ? VisualPrompts.prompt(forSceneID: request.id, theme: request.theme)
            : VisualPrompts.prompt(forCreatureID: request.id, theme: request.theme)
        do {
            for try await image in creator.images(for: [.text(prompt)], style: style, limit: 1) {
                if let cg = image.cgImage {
                    let scaled = cg.downscaled(maxPixel: maxPixel) ?? cg
                    VisualCache.shared.store(scaled, forKey: cacheKey)
                    return scaled
                }
            }
        } catch { return nil }
        return nil
    }
}
```
  Add a small `CGImage.downscaled(maxPixel:)` helper (CoreGraphics) in the same file. If the streaming/`cgImage`/`availableStyles` names differ, adjust to the SDK; keep the cache-key + prompt + fallback logic.
- [ ] **Step 3 — wire** as the default provider in `ZenWordOfDoomApp.swift`: `VisualProviderBox(provider: ImagePlaygroundVisualProvider())`.
- [ ] **Step 4 — build** → BUILD SUCCEEDED (compiles; simulator returns nil at runtime → fallback).
- [ ] **Step 5 — commit:** `feat(app): Image Playground visual provider`.

---

## Task 4: Bestiary portraits

**Files:** Modify `App/ZenWordOfDoom/BestiaryView.swift` (+ a small `ProceduralPortrait` view, new file or in-file).

- [ ] **Step 1 — `ProceduralPortrait`** (asset-free fallback): a small SwiftUI `Canvas` that draws a themed blobby silhouette from the creature id (reuse the deterministic-hash + lobed-blob approach from `RevealBackgroundView`/`CutSceneView`; a compact version is fine). Doom palette.
- [ ] **Step 2 — In `BestiaryView.row(for:)`,** for a **revealed** creature replace the `Image(systemName: "pawprint.fill")` thumbnail with:
```swift
GeneratedImageView(request: .init(id: creatureID, theme: .doom, kind: .creature), maxPixel: 96) {
    ProceduralPortrait(creatureID: creatureID)
}
.frame(width: 44, height: 44)
.clipShape(RoundedRectangle(cornerRadius: 8))
```
  Keep the hidden (not-revealed) rows exactly as they are (silhouette/redacted).
- [ ] **Step 3 — build** → BUILD SUCCEEDED. In the simulator, revealed rows show `ProceduralPortrait` (generation unavailable).
- [ ] **Step 4 — commit:** `feat(app): generated bestiary creature portraits`.

---

## Task 5: Cut-scene art

**Files:** Modify `App/ZenWordOfDoom/CutSceneView.swift`.

Layer a generated **scene** image under the existing animated procedural scene (fallback = current gradient scene). The generated image is the static base; ripples, vignette, creature pop-out, and poem stay on top and animated.

- [ ] **Step 1 — pass theme in.** `CutSceneData` has `scene`/`creature` ids but not theme. Derive theme in `CutSceneFactory` and add it to the data, OR pass `theme` into `CutSceneView` from `CutSceneContainerView` (which already computes `levelService.theme(forID:)`). Prefer: add `let theme: Theme` to `CutSceneView` and pass it from the container. Update the call site.
- [ ] **Step 2 — base layer.** In `CutSceneView.body`, wrap the procedural `scene` so a generated image sits beneath it:
```swift
ZStack {
    GeneratedImageView(request: .init(id: cutScene.scene, theme: theme, kind: .scene), maxPixel: 768) {
        scene            // existing procedural scene as the fallback
    }
    .ignoresSafeArea()
    // existing animated overlays (ripples/vignette/creature) remain ON TOP:
    scene.opacity(generatedSceneShown ? 0 : 1)  // see note
    ...
}
```
  Simpler, low-risk approach: keep `scene` as the animated layer always, and only ADD the generated image as a faint static backdrop *behind* it with reduced opacity, OR (cleanest) use `GeneratedImageView { scene }` as the whole background and drop the separate `scene` — but then the animated ripples/creature are lost when an image loads. **Decision:** keep the animated procedural `scene` as the primary visual (it carries the doom pop-out, which is core), and place the generated image as a **subtle backdrop behind it** at ~0.5 opacity for added texture. Implement:
```swift
ZStack {
    GeneratedImageView(request: .init(id: cutScene.scene, theme: theme, kind: .scene), maxPixel: 768) {
        Color.clear
    }
    .opacity(0.5)
    .ignoresSafeArea()

    scene.ignoresSafeArea()      // animated procedural layer stays on top
    // ...poemCard / continueButton unchanged...
}
```
  This adds generated atmosphere without disturbing the signature animated reveal. (The creature stays procedural for now — simpler; a generated creature pop-out can be a later enhancement.)
- [ ] **Step 3 — build** → BUILD SUCCEEDED. Simulator: generated backdrop unavailable → `Color.clear` → identical to today.
- [ ] **Step 4 — commit:** `feat(app): generated cut-scene backdrop art`.

---

## Final review

Dispatch a holistic review over the branch diff (focus: the provider/cache async flow, the fallback guarantee on the simulator path, that gameplay/level-select are untouched, and the `ImageCreator` API usage if Task 3 landed). Confirm `swift test` + app build green, then finish the branch (merge to `main`) via superpowers:finishing-a-development-branch.

**Note on Task 3 BLOCKED:** if `ImageCreator` is unavailable in the SDK, Tasks 1, 2, 4, 5 still merge — the app gains the seam, cache, prompts, and portrait/cut-scene *plumbing* showing procedural fallbacks, ready for the provider whenever the API is confirmed. Record the blocker in the merge notes.
