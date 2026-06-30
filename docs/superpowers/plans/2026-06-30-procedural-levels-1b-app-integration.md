# Procedural Levels — Plan 1b: App Integration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app play **procedurally generated** levels from the `LevelGen` package instead of the hand-authored `levels.json`, preserving the existing progression, bestiary, cut-scene, and level-select flows.

**Architecture:** Keep all pure, testable logic (ordering, progression math, themed asset pools) in the `LevelGen` package, verified by `swift test`. The app target gets a thin async `LevelService` that turns a level id into a `Level` (deterministically now; Foundation Models later), plus loading UX. The authored-content removal is the **last** task so the app compiles throughout the migration. Generation is `async` (the provider is `async throws` after Plan 1b's predecessor follow-up I-1), so the game screen loads behind a themed loader.

**Tech Stack:** Swift 5.9, SwiftUI, the `LevelGen`/`GameCore`/`WordEngine` SPM packages, XcodeGen (`project.yml` → generated `.xcodeproj`).

**Verification:**
- LevelGen tasks (1–2): `DEVELOPER_DIR=/Users/jsamuel/Downloads/Xcode-beta.app/Contents/Developer swift test`
- App-target tasks (3–9): regenerate + compile the app:
  ```
  xcodegen generate
  DEVELOPER_DIR=/Users/jsamuel/Downloads/Xcode-beta.app/Contents/Developer \
    xcodebuild -scheme ZenWordOfDoom \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath .build/xcode build CODE_SIGNING_ALLOWED=NO | tail -20
  ```
  Expect `** BUILD SUCCEEDED **`. Keep `swift test` green too (package tests).

---

## File Structure

**LevelGen (pure, tested) — modify/extend:**
- `Sources/LevelGen/ProceduralLevelLibrary.swift` — add ordering/progression API + a shared `standard` instance.
- `Sources/LevelGen/WheelPicker.swift` — make `wheelLength(for:)` usable (public) so level-select can show wheel size without generating a level.
- `Sources/LevelGen/SceneCreaturePicker.swift` — add `ThemePools.zenDoom` default themed pools.
- Tests: `Tests/LevelGenTests/ProceduralLevelLibraryTests.swift` (extend), `Tests/LevelGenTests/ThemePoolsTests.swift` (new).

**App target — add:**
- `App/ZenWordOfDoom/LevelService.swift` — async level resolution + ordering pass-throughs; `@MainActor ObservableObject`, injected into the environment.
- `App/ZenWordOfDoom/CutSceneFactory.swift` — synthesize a themed breath (`CutSceneData`) per level.

**App target — modify:**
- `ZenWordOfDoomApp.swift`, `ContentView.swift` — create/inject `LevelService`.
- `GameStore.swift` — progression via `ProceduralLevelLibrary` index math.
- `GameContainerView.swift` — async load + themed loader; extract inner `GamePlayView`.
- `CutSceneContainerView.swift` — synthesized cut scene + library `nextID`.
- `LevelSelectView.swift` — windowed procedural list + synthesized section titles.
- `BestiaryView.swift` — creature list from `ThemePools.zenDoom`.
- `project.yml` — add `LevelGen` product to the app target's dependencies.

**Retire (Task 9):** `Sources/LevelKit/LevelLibrary.swift`, `LevelData.swift`, `PackData.swift`, `Resources/levels.json`, `Resources/packs.json`, and the LevelKit tests that load them. **Keep** `CutSceneData.swift` + `CutSceneView` (the synthesized cut scene reuses the `CutSceneData` type) and `cutscenes.json` may be deleted (no longer read).

---

## Task 1: Ordering & progression API on ProceduralLevelLibrary

**Files:**
- Modify: `Sources/LevelGen/ProceduralLevelLibrary.swift`
- Modify: `Sources/LevelGen/WheelPicker.swift` (make `wheelLength(for:)` `public` if not already)
- Test: `Tests/LevelGenTests/ProceduralLevelLibraryTests.swift`

Order N maps to a stable `LevelSeed` whose `index == N`, and ids are reversible, so progression is pure index math — no infinite list needed.

- [ ] **Step 1 — Write failing tests.** Add to `ProceduralLevelLibraryTests`:
```swift
func testOrderIDRoundTrip() {
    let lib = ProceduralLevelLibrary()
    for order in [0, 1, 9, 10, 25, 100] {
        let id = lib.id(atOrder: order)
        XCTAssertEqual(lib.order(forID: id), order)
    }
}
func testNextIDAdvancesByOne() {
    let lib = ProceduralLevelLibrary()
    let id5 = lib.id(atOrder: 5)
    XCTAssertEqual(lib.nextID(after: id5), lib.id(atOrder: 6))
}
func testNextIDNilForUnknownID() {
    XCTAssertNil(ProceduralLevelLibrary().nextID(after: "not-a-real-id"))
}
func testIDsThroughIsContiguous() {
    let lib = ProceduralLevelLibrary()
    let ids = lib.ids(through: 12)
    XCTAssertEqual(ids.count, 13)
    XCTAssertEqual(ids.first, lib.id(atOrder: 0))
    XCTAssertEqual(ids.last, lib.id(atOrder: 12))
}
func testWheelSizeForIDMatchesBand() {
    let lib = ProceduralLevelLibrary()
    let id = lib.id(atOrder: 0) // pack 0 → easy
    XCTAssertEqual(lib.wheelSize(forID: id), WheelPicker.wheelLength(for: .easy))
}
func testStandardIsUsable() {
    XCTAssertEqual(ProceduralLevelLibrary.standard.id(atOrder: 0),
                   ProceduralLevelLibrary().id(atOrder: 0))
}
```
- [ ] **Step 2 — Run, watch fail** (`swift test --filter ProceduralLevelLibraryTests`). Expect compile failure (methods undefined).
- [ ] **Step 3 — Implement.** Add to `ProceduralLevelLibrary`:
```swift
/// A shared default instance so progression (GameStore) and generation
/// (LevelService) order levels identically.
public static let standard = ProceduralLevelLibrary()

/// The id at a given play order (order is the level index).
public func id(atOrder order: Int) -> String { seed(atOrder: order).id }

/// The play order of a level id, or nil if the id isn't a valid library id.
public func order(forID id: String) -> Int? { seed(forID: id)?.index }

/// The id of the level after `id` in play order, or nil if `id` is unknown.
public func nextID(after id: String) -> String? {
    guard let order = order(forID: id) else { return nil }
    return id(atOrder: order + 1)
}

/// Contiguous ids from order 0 through `order` inclusive (for level select).
public func ids(through order: Int) -> [String] {
    guard order >= 0 else { return [] }
    return (0...order).map(id(atOrder:))
}

/// The wheel size for a level id, derived from its band without generating it.
public func wheelSize(forID id: String) -> Int {
    guard let seed = seed(forID: id) else { return 0 }
    return WheelPicker.wheelLength(for: seed.band)
}
```
If `WheelPicker.wheelLength(for:)` is `internal`, change it to `public` (and confirm no signature change otherwise).
- [ ] **Step 4 — Run, watch pass** (`swift test --filter ProceduralLevelLibraryTests`, then full `swift test`). Expect all pass.
- [ ] **Step 5 — Commit:** `feat(levelgen): ordering & progression API on ProceduralLevelLibrary`.

---

## Task 2: Default themed asset pools (ThemePools.zenDoom)

**Files:**
- Modify: `Sources/LevelGen/SceneCreaturePicker.swift`
- Test: `Tests/LevelGenTests/ThemePoolsTests.swift` (new)

Scene/creature ids are arbitrary stable slugs (the app hashes them to procedural palettes/silhouettes today; Plan 3 maps them to image prompts). Provide curated, evocative slugs per theme.

- [ ] **Step 1 — Write failing test** (`ThemePoolsTests.swift`):
```swift
import XCTest
import GameCore
@testable import LevelGen

final class ThemePoolsTests: XCTestCase {
    func testDefaultPoolsNonEmptyPerTheme() {
        let pools = ThemePools.zenDoom
        for theme in Theme.allCases {
            XCTAssertGreaterThanOrEqual(pools.scenes[theme]?.count ?? 0, 4)
            XCTAssertGreaterThanOrEqual(pools.creatures[theme]?.count ?? 0, 4)
        }
    }
    func testPickerOverDefaultPoolsIsStableAndInPool() {
        let picker = SceneCreaturePicker(pools: .zenDoom)
        let a = picker.pick(theme: .doom, index: 3)
        let b = picker.pick(theme: .doom, index: 3)
        XCTAssertEqual(a.sceneID, b.sceneID)
        XCTAssertEqual(a.creatureID, b.creatureID)
        XCTAssertTrue(ThemePools.zenDoom.scenes[.doom]!.contains(a.sceneID))
        XCTAssertTrue(ThemePools.zenDoom.creatures[.doom]!.contains(a.creatureID))
    }
}
```
- [ ] **Step 2 — Run, watch fail.** Expect compile failure (`.zenDoom` undefined).
- [ ] **Step 3 — Implement.** Add to `SceneCreaturePicker.swift`:
```swift
public extension ThemePools {
    /// Default curated themed asset ids. Slugs are evocative and IP-free so a
    /// later image-generation source can map them to prompts within content
    /// guardrails (mood over monsters).
    static let zenDoom = ThemePools(
        scenes: [
            .zen: ["still-pond", "moss-garden", "bamboo-grove", "misty-peak",
                   "lantern-path", "sand-ripples", "willow-bank"],
            .doom: ["sunken-crypt", "black-abyss", "thorn-hollow", "ruined-shrine",
                    "ashen-moor", "drowned-temple", "ember-catacomb"],
        ],
        creatures: [
            .zen: ["koi-spirit", "stone-guardian", "crane-shade", "lotus-wisp",
                   "moss-golem", "paper-fox"],
            .doom: ["deep-tentacle", "gloom-eye", "bone-wraith", "mask-fiend",
                    "thorn-revenant", "ash-maw"],
        ]
    )
}
```
- [ ] **Step 4 — Run, watch pass** (filter `ThemePoolsTests`, then full `swift test`).
- [ ] **Step 5 — Commit:** `feat(levelgen): default Zen/Doom themed asset pools`.

---

## Task 3: LevelService + environment injection

**Files:**
- Create: `App/ZenWordOfDoom/LevelService.swift`
- Modify: `App/ZenWordOfDoom/ZenWordOfDoomApp.swift`, `App/ZenWordOfDoom/ContentView.swift`

The async seam that turns a level id into a `Level`. Deterministic provider now; the same surface accepts a Foundation Models provider in Plan 2.

- [ ] **Step 1 — Create `LevelService.swift`:**
```swift
import Foundation
import GameCore
import LevelGen

/// Resolves level ids to playable `Level`s and exposes the procedural play
/// order. Generation is async (a Foundation Models word provider slots in
/// later); today it is deterministic and effectively instant.
@MainActor
final class LevelService: ObservableObject {
    private let library = ProceduralLevelLibrary.standard
    private let generator: ProceduralGenerator

    init(wordProvider: any ThemedWordProvider = DeterministicWordProvider()) {
        self.generator = ProceduralGenerator(wordProvider: wordProvider,
                                             pools: .zenDoom)
    }

    /// Generate (or in future, fetch from cache) the level for an id. Falls back
    /// to a sample level if the id is unknown or generation fails, so the player
    /// is never stranded on a blank screen.
    func level(id: String) async -> Level {
        guard let seed = library.seed(forID: id) else { return SampleLevel.make() }
        do { return try await generator.level(for: seed) }
        catch { return SampleLevel.make() }
    }

    // Ordering pass-throughs (pure, synchronous).
    func id(atOrder order: Int) -> String { library.id(atOrder: order) }
    func order(forID id: String) -> Int? { library.order(forID: id) }
    func nextID(after id: String) -> String? { library.nextID(after: id) }
    func ids(through order: Int) -> [String] { library.ids(through: order) }
    func wheelSize(forID id: String) -> Int { library.wheelSize(forID: id) }

    /// The theme for an id (for themed loaders / cut scenes), defaulting to zen.
    func theme(forID id: String) -> Theme {
        library.seed(forID: id)?.theme ?? .zen
    }
}
```
- [ ] **Step 2 — Inject at the root.** In `ZenWordOfDoomApp.swift` add `@StateObject private var levelService = LevelService()` and `.environmentObject(levelService)` on `ContentView()`.
- [ ] **Step 3 — Build** (xcodebuild command above). Expect BUILD SUCCEEDED (service compiles; not yet used elsewhere). `ContentView` still imports LevelKit — fine.
- [ ] **Step 4 — Commit:** `feat(app): LevelService async level resolution + ordering`.

---

## Task 4: GameStore progression via ProceduralLevelLibrary

**Files:**
- Modify: `App/ZenWordOfDoom/GameStore.swift`

Replace the `LevelLibrary.orderedLevelIDs()`-based unlock logic with index math, so progression works for the endless procedural sequence.

- [ ] **Step 1 — Edit `GameStore`.** Add `import LevelGen` and `private let library = ProceduralLevelLibrary.standard`. Replace `isUnlocked` and `nextUnclearedLevelID`:
```swift
/// Levels unlock linearly: order 0 is always open; every later level opens
/// once the level immediately before it (by play order) has been cleared.
func isUnlocked(_ levelID: String) -> Bool {
    guard let order = library.order(forID: levelID) else { return false }
    return order == 0 || isCleared(library.id(atOrder: order - 1))
}

/// The first level in play order the player has not yet cleared.
var nextUnclearedLevelID: String? {
    var order = 0
    while order < 100_000 {            // safety bound; player can't clear ∞
        let id = library.id(atOrder: order)
        if !isCleared(id) { return id }
        order += 1
    }
    return nil
}
```
Remove `import LevelKit` from `GameStore.swift` if nothing else there needs it (it doesn't).
- [ ] **Step 2 — Build.** Expect BUILD SUCCEEDED.
- [ ] **Step 3 — Commit:** `feat(app): linear progression over procedural level order`.

---

## Task 5: Async GameContainerView with a themed loader

**Files:**
- Modify: `App/ZenWordOfDoom/GameContainerView.swift`

The level is now produced asynchronously, so the container can't build the `GameViewModel` in `init`. Show a themed loader until the `Level` resolves, then render an inner `GamePlayView` that owns the `@StateObject GameViewModel`.

- [ ] **Step 1 — Restructure.** Replace `GameContainerView` so it:
  - takes `levelID` (drop the `settings`/`store` init params; read them from the environment),
  - uses `@EnvironmentObject private var levelService: LevelService`,
  - holds `@State private var loaded: Level?`,
  - `.task { loaded = await levelService.level(id: levelID) }`,
  - shows `LoadingView(theme:)` while `loaded == nil`, else `GamePlayView(level:)`.
  Extract the existing body (HUD/grid/ribbon/wheel/controls/completion) into a new `GamePlayView: View` that takes `let level: Level` and creates `@StateObject private var model: GameViewModel` via an `init(level:settings:store:)`, reading `settings`/`store` from environment to pass in. Keep all existing gameplay behavior, voice wiring, and the `onChange(of: model.isComplete)` → `router.push(.cutScene(afterLevelID: levelID))` exactly as-is.
  - `packTitle` becomes theme/band derived: `"\(theme.capitalized) · \(band.capitalized)"` using `level.band` and `levelService.theme(forID: levelID)`.
  - The loader:
```swift
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
```
- [ ] **Step 2 — Update the call site** in `ContentView.swift`: `GameContainerView(levelID: levelID)` (drop the extra args).
- [ ] **Step 3 — Build.** Expect BUILD SUCCEEDED. Manually reason through: loader shows, then play screen; completion still routes to the cut scene.
- [ ] **Step 4 — Commit:** `feat(app): async level loading with a themed loader`.

---

## Task 6: Synthesized cut scenes

**Files:**
- Create: `App/ZenWordOfDoom/CutSceneFactory.swift`
- Modify: `App/ZenWordOfDoom/CutSceneContainerView.swift`

Procedural ids have no authored `cutscenes.json` entry. Synthesize a themed breath from the level's theme + visuals (reuse the `CutSceneData` type).

- [ ] **Step 1 — Create `CutSceneFactory.swift`:**
```swift
import Foundation
import LevelKit
import LevelGen

/// Builds a between-levels "breath" for a procedurally generated level. The
/// scene/creature come from the just-cleared level; the poem is a short themed
/// couplet chosen deterministically from the id.
enum CutSceneFactory {
    static func cutScene(forLevelID id: String,
                         service: LevelService,
                         sceneID: String,
                         creatureID: String) -> CutSceneData {
        let theme = service.theme(forID: id)
        let order = service.order(forID: id) ?? 0
        let poems = theme == .zen ? zenPoems : doomPoems
        let poem = poems[order % poems.count]
        return CutSceneData(id: id, scene: sceneID, creature: creatureID,
                            poem: poem, popoutDelay: theme == .zen ? 2.4 : 1.6)
    }

    private static let zenPoems: [[String]] = [
        ["still water holds", "the whole sky —", "then a ripple"],
        ["one breath in,", "the garden", "lets you go"],
        ["moss on old stone,", "patient as", "the morning"],
    ]
    private static let doomPoems: [[String]] = [
        ["the calm was bait —", "something below", "uncoils"],
        ["you spelled the words;", "the dark", "spelled you"],
        ["peace is a mask", "the abyss", "wears well"],
    ]
}
```
- [ ] **Step 2 — Update `CutSceneContainerView`.** Add `@EnvironmentObject private var levelService: LevelService`. Replace the body's source of `CutSceneData` and `advance()`:
  - It needs the just-cleared level's scene/creature ids. Resolve them with `.task { loaded = await levelService.level(id: afterLevelID) }` into `@State private var loaded: Level?`; while nil, show `Color.clear` (or a brief progress) then build via `CutSceneFactory.cutScene(forLevelID:service:sceneID:creatureID:)`.
  - `advance()` uses `levelService.nextID(after: afterLevelID)` instead of `LevelLibrary.nextLevelID(after:)`; the `[.levelSelect, .game(next)]` / `popToRoot()` behavior is unchanged.
- [ ] **Step 3 — Build.** Expect BUILD SUCCEEDED.
- [ ] **Step 4 — Commit:** `feat(app): synthesized themed cut scenes for procedural levels`.

---

## Task 7: Level select over the procedural sequence

**Files:**
- Modify: `App/ZenWordOfDoom/LevelSelectView.swift`

Show a windowed list: every cleared level, the next unlocked, and a short locked preview, grouped into themed sections. Subtitles are seed-derived (no generation).

- [ ] **Step 1 — Edit `LevelSelectView`.** Add `@EnvironmentObject private var levelService: LevelService`. Replace `packs`/rows:
  - Compute the horizon: furthest unlocked order + a small preview, rounded up to a pack boundary.
```swift
private var visibleIDs: [String] {
    // furthest order the player can currently reach
    var furthest = 0
    while levelService.order(forID: levelService.id(atOrder: furthest))
            != nil, store.isUnlocked(levelService.id(atOrder: furthest)),
          furthest < 100_000 { furthest += 1 }
    let horizon = furthest + 3          // a few locked previews
    return levelService.ids(through: horizon)
}
```
  - Group `visibleIDs` into sections of 10 (the library's pack size) titled by the first id's theme + band, e.g. `"Zen · Easy"`. Derive theme via `levelService.theme(forID:)` and band via `DifficultyBand(wheelSize: levelService.wheelSize(forID: id))`.
  - The row's subtitle no longer needs a generated `Level`: use `levelService.wheelSize(forID: id)` and `DifficultyBand(wheelSize:)` for `"\(band.capitalized) · \(n) letters"`, plus `Best \(score)` from `store.state.progress[id]` when cleared. Keep the lock/clear icons and the `store.isUnlocked` gating exactly as-is.
- [ ] **Step 2 — Build.** Expect BUILD SUCCEEDED.
- [ ] **Step 3 — Commit:** `feat(app): level select over the procedural sequence`.

---

## Task 8: Bestiary from themed creature pool

**Files:**
- Modify: `App/ZenWordOfDoom/BestiaryView.swift`

The bestiary listed every creature across the authored library. With endless procedural levels, list the **doom** creature pool (the monsters the player can encounter), keeping the revealed/hidden treatment.

- [ ] **Step 1 — Edit `BestiaryView`.** Replace `allCreatureIDs` with the curated pool:
```swift
import LevelGen
// ...
private var allCreatureIDs: [String] {
    (ThemePools.zenDoom.creatures[.doom] ?? []).sorted()
}
```
Remove `import LevelKit`. The header `"\(revealed) of \(allCreatureIDs.count) revealed"` and rows stay the same.
- [ ] **Step 2 — Build.** Expect BUILD SUCCEEDED.
- [ ] **Step 3 — Commit:** `feat(app): bestiary lists the themed doom creature pool`.

---

## Task 9: Wire the package dependency & retire authored content

**Files:**
- Modify: `project.yml`
- Delete: `Sources/LevelKit/LevelLibrary.swift`, `Sources/LevelKit/LevelData.swift`, `Sources/LevelKit/PackData.swift`, `Sources/LevelKit/Resources/levels.json`, `Sources/LevelKit/Resources/packs.json`, `Sources/LevelKit/Resources/cutscenes.json`
- Modify/Delete: LevelKit tests that load the deleted JSON (`Tests/LevelKitTests/*`), and `Package.swift` if a resource reference must change
- Keep: `Sources/LevelKit/CutSceneData.swift`, `Sources/LevelKit/LevelValidator.swift` only if still referenced (otherwise delete), `App/ZenWordOfDoom/CutSceneView.swift`

- [ ] **Step 1 — Add the dependency.** In `project.yml`, under the app target's `dependencies:`, add:
```yaml
      - package: ZenWordOfDoomKit
        product: LevelGen
```
- [ ] **Step 2 — Confirm no remaining `LevelLibrary` references.** Run `grep -rn "LevelLibrary" App Sources` — expect only the file about to be deleted. Run `grep -rln "import LevelKit" App` — expect only files that use `CutSceneData`/`CutSceneView` (`CutSceneContainerView.swift`, `CutSceneView.swift`, `CutSceneFactory.swift`).
- [ ] **Step 3 — Delete authored level content** (the files listed above). If `LevelValidator` or any LevelKit test references the deleted types/JSON, delete those tests too; if `LevelValidator` only validated authored levels, delete it. Update `Package.swift` so the LevelKit target still builds (it keeps `CutSceneData`; drop resource processing for deleted JSON only if it was explicitly listed — it likely uses `.process("Resources")`, which tolerates remaining files like `cutscenes.json`; if you deleted all LevelKit resources, remove the `resources:` clause for that target).
- [ ] **Step 4 — Regenerate + build + test.**
  - `xcodegen generate`
  - `swift test` (packages) → green, no references to deleted types.
  - `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`.
- [ ] **Step 5 — Commit:** `feat(app): play procedural levels; retire authored levels.json`.

---

## Final review

After all tasks: dispatch a holistic code review over the whole branch diff (app integration + LevelGen additions), confirm `swift test` green and the app builds, then finish the branch (merge to `main`) via superpowers:finishing-a-development-branch.

**Out of scope (later plans):** Foundation Models word provider + per-level word cache (Plan 2); on-device image generation via the scene/creature ids (Plan 3). The `LevelService` word-provider injection point and the scene/creature id slugs are the seams those plans plug into.
