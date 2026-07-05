# Zen Word of Doom — Technical Architecture

Companion to [`SPEC.md`](SPEC.md). Describes the system **as shipped** through
v0.3: stack, module boundaries, the generation pipeline, and the app layer
that plays it. This is the actual codebase, not a plan — see §7 for the
earlier proposal this document replaced.

---

## 1. Stack

| Concern | Choice | Why |
| --- | --- | --- |
| Language | **Swift 5.9+** (tools version), app deployment iOS 17+/26.5 CI | Native, performant, first-class on iOS |
| App chrome / navigation / HUD / game surface | **SwiftUI** | Declarative, one `NavigationStack`, accessibility built-in |
| Game rules & generation | **Two pure Swift Package Manager targets** (`GameCore`, `LevelGen`) | Headless-testable, no UIKit dependency, fast `swift test` |
| Dictionary (runtime validation) | **iOS built-in (`UITextChecker`)** via `SystemDictionary` | System spell-checker; no bundled word list or license needed for validation |
| Word corpus (level authoring) | **Bundled resource lists** in `LevelGen` (`GeneralWordList`, `CommonWords`, `ThemeLexicon`) | Deterministic pool for grid generation and the always-available fallback |
| On-device word enrichment | **Foundation Models** (`FoundationModelsWordProvider`), decorating the deterministic provider | Optional; degrades to the deterministic floor everywhere it's unavailable |
| Scene/creature art | **Image Playground** (`ImagePlaygroundVisualProvider`), decorating bundled + procedural art | Optional on-device generation; bundled art and a procedural SwiftUI fallback always render something |
| Audio | **AVFoundation** (`AVAudioSoundEngine`, a raw `AVAudioSourceNode` render callback) | Generative drone/arpeggio bed reactive to `stir`, no external audio assets |
| Voice | **Speech (`SFSpeechRecognizer`)** + **AVFoundation** | On-device recognition, mic capture (`VoiceInput`) |
| Persistence | **Codable JSON file** in Application Support (`GameStore`/`SaveState`) | Simple, inspectable, no CloudKit/SwiftData dependency |
| Monetization | **StoreKit 2** (`StoreKitStoreService`) + **Google Mobile Ads** (`AdMobAdService`) | Consumable serenity + non-consumable ad removal; native ads gated to post-grace-period cut scenes |
| Packaging | **Swift Package Manager** for `GameCore`/`LevelGen`; an Xcode app target for the UI | Modular, headless-testable core; standard iOS app shell |

---

## 2. Module layout

```
ZenWordOfDoom.xcodeproj/          # App target (SwiftUI @main, app lifecycle)
Package.swift                     # SPM package "ZenWordOfDoomKit"
Sources/
  GameCore/     # Pure Swift, no UIKit: rules, models, scoring, seeded RNG,
                # FNV1a, save state, store types, cosmetics catalog, cut-scene
                # data model, sound-engine protocol + musical-palette model
  LevelGen/     # Procedural generation: word corpus/lexicons, wheel/scene/
                # creature pickers, crossword layout engine, deterministic
                # word provider, ProceduralLevelLibrary (campaign ordering),
                # DailyPuzzle, PackCatalog (packs + capstones), Primes
                # (theme-flip cadence), LevelGenError
App/ZenWordOfDoom/                # SwiftUI app: navigation, views, view models,
                                   # persistence glue, on-device AI decorators,
                                   # StoreKit/AdMob services
App/ZenWordOfDoomTests/           # XCTest target for the app layer (store,
                                   # view model, bundled-visuals lookup)
Tests/GameCoreTests/              # XCTest for GameCore
Tests/LevelGenTests/              # XCTest for LevelGen
```

`GameCore` has zero dependencies. `LevelGen` depends only on `GameCore`.
Neither imports UIKit/SwiftUI/AVFoundation — every on-device-AI or
platform-specific integration point is a protocol (`ThemedWordProvider`,
`SceneVisualProvider`, `SoundEngine`, `StoreService`, `AdService`,
`WordValidating`) implemented in the app target, which is where UIKit-only
code like `UITextChecker` lives (`App/ZenWordOfDoom/SystemDictionary.swift`).

`Package.swift` exposes `GameCore` and `LevelGen` as libraries; the Xcode
project consumes them as local package dependencies of the app target, plus
a separate `ZenWordOfDoomTests` Xcode test target for app-layer coverage that
needs `@testable import` of app types (not exposed by the package).

---

## 3. Core domain model (GameCore)

```swift
public struct LetterTile: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: Int          // stable per-level tile identity (handles duplicates)
    public let letter: Character
}

public struct Wheel: Equatable, Sendable {
    public let tiles: [LetterTile]      // 5...9 tiles
    public var size: Int { tiles.count } // == max word length N
    public var multiset: LetterMultiset { ... }
}

public struct GridSlot: Identifiable, Equatable, Sendable {
    public let id: Int
    public let answer: String            // hidden until found
    public let origin: GridCoord
    public let direction: Direction      // .across / .down
    public var cells: [GridCoord] { ... } // derived
}

public enum LevelFormat: Equatable, Sendable {
    case crossword                       // fill every grid slot (default)
    case pangramHunt(target: Int)        // pack-capstone boss: no grid — find
                                          // the pangram plus `target` total words
}

public struct Level: Identifiable, Sendable {
    public let id: String
    public let wheel: Wheel
    public let slots: [GridSlot]
    public let sceneID: String
    public let creatureID: String
    public let format: LevelFormat
    public var band: DifficultyBand { DifficultyBand(wheelSize: wheel.size) }
}

public enum SubmissionResult: Equatable, Sendable {
    case filledSlots([Int])              // matched grid slot ids
    case bonusWord(String)               // valid, not in grid
    case invalid(InvalidReason)
}
```

### 3.1 Word submission pipeline (`GameEngine.submit`)

```
Word string (from tap/swipe builder or voice)
  → uppercase, length 3...N ?
  → buildable from wheel multiset ?
  → already found this level ?
  → matches an unsolved grid slot's answer ?
        yes → fill cells, score, bump stir       → .filledSlots
        no  → run WordValidating (SystemDictionary)
                valid   → bonus word, smaller score, bump stir → .bonusWord
                invalid →                                       .invalid
```

A word matching a grid answer fills the slot **without** consulting the
runtime dictionary: the level generator already guaranteed grid answers are
real, buildable words drawn from `LevelGen`'s corpus, and `UITextChecker`'s
word list can disagree with that corpus. Only bonus words (anything not in
the grid) are gated by `SystemDictionary`.

`WordBuilder` is the single state machine (`begin`/`extend`/`backtrack`/
`submit`/`cancel`) that both tap and swipe drive identically; voice
(`GameViewModel.submitSpoken`) greedily maps recognized letters onto unused
wheel tiles and then calls the same `submit()` path.

### 3.2 Stir (the reveal meter) and Doom mode

`GameEngine.stir` (0…1) is **progress-derived, not increment-only**: it
tracks `0.85 × completionFraction` (grid slots solved, or the pangram/word
mix for boss levels) plus small additive nudges for bonus words and hints,
capped at 0.95 until the clear snaps it to 1. This makes the reveal
proportional across every grid size instead of needing per-word tuning.

Doom mode (`GameMode.doom(timeLimit:)`) races a timer that is a **bonus
window, not a forfeit**. Every point earned is scaled by
`GameEngine.scoreMultiplier`, which the view model keeps in step with the
countdown via `Scoring.doomMultiplier(timeRemaining:timeLimit:)`: more than
2/3 of the limit remaining scores **4x**, more than 1/3 **3x**, any time
left on the clock **2x**. On expiry (`GameViewModel.handleDoomExpiry`) the
multiplier drops to **1x** — words still land, slots still fill, and points
keep flowing at base value (stir and completion are unaffected). There is
**no retry** — the player dismisses a "the doom bonus is gone" overlay and
keeps playing the same level toward the clear. A doom-expired clear still
records progress, streak, and bestiary, but is excluded from serenity
rewards (`GameStore.recordClear` `voided:` parameter; see §5.2 for the
current economy numbers).

---

## 4. Level generation (LevelGen)

Levels are **generated at runtime**, not loaded from bundled JSON per level.
`ProceduralGenerator.level(for: LevelSeed) async throws -> Level` runs a
deterministic pipeline, seeded end-to-end so the same seed always produces
the same level:

```
LevelSeed (theme, band, index)
  → scene + creature picked (SceneCreaturePicker, seeded)
  → wheel picked from the pre-selected KNOWN-GOOD anchor pools (AnchorPools,
    generated offline by scripts/generate-anchor-pools.sh: every anchor is a
    common corpus word passing sanity gates, tiered by how many common words
    its letters build — easy = rich pool, hard = barely more than the grid
    demands). The order's DifficultyTier selects the pool; the scene's slug
    words steer WHICH anchor via SceneAffinity — the image inspires the
    letters — through a seeded per-scene cycle of the top-24 matches, with
    the previous level's letters explicitly avoided so consecutive levels
    never repeat a wheel (WheelPicker)
  → [pack capstone?] → Pangram-Hunt boss, no grid (LevelFormat.pangramHunt) —
    the anchor is a real, common N-letter word, so the pangram exists and is
    recognizable
  → word pool requested from a ThemedWordProvider, buildable from the wheel
  → pool filtered to "interesting" words (on-theme or common) with a fallback
    to the full pool if that filter starves the grid
  → CrosswordLayoutEngine lays out an interlocking grid (seeded)
  → Level
```

Scene metadata is derived, not curated: a slug's hyphen-separated words ARE
its tags ("moss-garden" → MOSS, GARDEN; `SceneAffinity`), so adding a new
illustration is just adding its slug + asset — no word lists or mapping
tables. The daily puzzle's word→image pairing works the same way
(`WordOfTheDayImages`: balanced affinity assignment, no per-word map).

Failure is a typed `LevelGenError` (`noAnchorWord`, `emptyGrid`), not a
crash — every seed in the shipped libraries is covered by
`SolvabilitySweepTests`, so these exist to degrade a genuinely bad seed to a
retry screen rather than a `precondition` trap.

### 4.1 Ordering, packs, and the daily puzzle

- **`ProceduralLevelLibrary`** maps a play order to a stable `LevelSeed`.
  Difficulty is a 2-D ladder: each pack walks one wheel size, sizes cycle
  5→9 across packs (`band = pack % 5`), and every full size cycle escalates
  the richness **tier** (`tier(atOrder:)`: easy → medium → hard anchor
  pools; see `DifficultyTier`) — a ~150-level ramp, after which the
  infinite tail keeps cycling sizes at hard tier. Boss word-count targets
  bump with tier (`PackCatalog.pangramTarget(for:tier:)`). Theme starts
  `.zen` and permanently flips each time a prime-numbered level (1-indexed)
  is crossed, so a pack can contain a mix of themes.
- **`PackCatalog`** overlays named packs on that order and marks each pack's
  last level as a capstone (a `pangramHunt` boss revealing a signature
  creature).
- **`DailyPuzzle`** (`daily-yyyy-MM-dd` ids) derives a `LevelSeed` from
  `FNV1a.hash(id)` — **the same puzzle globally, for every player, on a given
  calendar day** — rotated through the mid-game bands (medium/hard/expert)
  with the theme flipping on the hash. `LevelService` re-keys the generated
  level by the daily id so progress and the streak land on that day. The
  streak advances on **any** clear (campaign or daily), not merely on
  opening the app.
- **`Primes`** provides the prime-count helper driving the theme-flip
  cadence above.

### 4.2 On-device AI as decorators, never a hard dependency

Both AI integration points follow the same shape: **wrap a deterministic
provider, only replace its output when generation actually succeeds and
passes a hard validation filter, and always have a working floor.**

- **Words** (`FoundationModelsWordProvider`, app target): checks
  `SystemLanguageModel.default.availability`; when unavailable (every
  simulator, every device without Apple Intelligence, CI) it returns the
  `DeterministicWordProvider` floor untouched. When available, model
  candidates are raced against a 20s timeout and merged with
  `WordPoolBuilder.merge`, which re-validates every candidate word against
  the wheel and the dictionary before it's allowed to displace a
  deterministic-floor word. Results are cached per wheel+theme
  (`WordPoolCache`).
- **Art** (`ImagePlaygroundVisualProvider`, app target): tries
  `ImageCreator()`; on any failure or a 30s timeout it returns `nil`, and
  `GeneratedImageView` falls back to bundled pre-rendered art
  (`BundledVisuals`) for the slug, and finally to a fully procedural SwiftUI
  reveal (`RevealBackgroundView`) if no bundled art exists either. Simulator
  and CI runs always land on the bundled/procedural fallback — no on-device
  model is invoked or required for the game to be playable/testable there.

---

## 5. App layer

- **`AppRouter`** — a single `@Published var path: [Screen]` driving one
  `NavigationStack` rooted at `MenuView` (`ContentView` maps each `Screen`
  case to its destination view). No secondary navigation controllers.
- **`LevelService`** — resolves a level id to a `Level` **asynchronously**
  and **memoizes** the result in an in-memory `[String: Level]` cache so
  revisiting a level (e.g. after a cut scene) doesn't regenerate it. Detects
  daily ids and routes them through `DailyPuzzle.seed(forID:)` instead of the
  campaign library; a generation failure (`LevelGenError`) resolves to `nil`
  and the container view shows a retry state rather than stranding the
  player on a mislabeled level.
- **`GameStore`** — owns the persisted `SaveState` (serenity, per-level
  progress, lifetime stats, bestiary, premium entitlement mirror, owned/
  equipped cosmetics, processed StoreKit transaction ids), serialized as
  **Codable JSON to a file in Application Support** (or an injectable URL for
  tests). Every mutation persists immediately; `Codable` decoding defaults
  every field so older saves missing newer keys (e.g. pre-monetization
  saves) load intact. Meaning changes to existing data go through an
  explicit `SaveState.schemaVersion` migration instead (v1 → v2 clears
  per-level progress — the level content was regenerated wholesale — while
  serenity, premium, transactions, cosmetics, bestiary, and stats survive).
- **`GameViewModel`** — bridges the pure `GameEngine` to SwiftUI: owns tap/
  swipe/voice input, the hint flow (seeded deterministic reveal order via
  `FNV1a` + reveal count), the doom timer, and completion (recording the
  clear into `GameStore`, computing the serenity delta, and driving the
  clear-summary overlay).
- **Art chain** — `SceneRevealView` picks bundled real art
  (`BundledVisuals`) or the procedural fallback for the base scene, then
  layers the creature in via `GeneratedImageView` (which itself races live
  generation against the bundled/procedural fallback, per §4.2), applying a
  stir-driven desaturate/red-cast/vignette treatment and the equipped Shrine
  palette's hue/tint.
- **`AVAudioSoundEngine`** — a single `AVAudioSourceNode` render callback
  synthesizes a continuous drone + slow arpeggio from a `MusicalPalette`
  (crossfaded toward the "doom" palette as `stir` rises — the reactive doom
  bus) plus short one-shot cues, entirely generative (no audio assets, not
  verifiable in CI/simulator, so it's best-effort and fully guarded).

### 5.1 Monetization & cosmetics (added v0.3)

- **`StoreKitStoreService`** (StoreKit 2): loads products, runs purchases
  with on-device signed verification (no backend), listens for
  `Transaction.updates` (Ask to Buy, refunds, cross-device purchases,
  replayed unfinished transactions), and reports deliveries via closures so
  `GameStore` stays the single writer of persisted state.
  `SaveState.markTransactionProcessed` dedupes replayed consumable
  transactions by id (bounded history of the last 50).
- **`AdMobAdService`** (Google Mobile Ads): starts the SDK lazily (premium
  players never pay the startup cost), requests App Tracking Transparency
  in context before the first ad, and serves non-personalized ads unless
  both the user's setting and ATT authorization allow personalization.
  Native ads only — the seam (`AdService`) falls back to a timed house card
  on no-fill/timeout, never leaving the player without a "continue" path.
- **`AdPolicy`** (GameCore): pack 1 (play orders `0..<10`, `adFreeLevelCount`)
  is an ad-free grace period, including the breath after its capstone;
  premium removes ads entirely; ads never appear anywhere else in the app.
- **`ShrineView` + `CosmeticsCatalog`** (GameCore): a fixed catalog of scene
  palettes and cut-scene poem sets, purchased with serenity and equipped
  (never re-purchased). This is the serenity sink — the reason the currency
  is worth accumulating beyond hints.

### 5.2 Serenity economy (implementation seams)

The **authoritative numbers, faucet/sink tables, design target, and change
checklist live in [`ECONOMY.md`](ECONOMY.md)** — one document, no
duplicated tables to drift. What belongs here is where the economy hooks
into code:

- `GameCore.Economy` is the single price list; no other file hardcodes an
  amount. `StoreItem.serenityAmount` (Store.swift) holds IAP contents.
- `GameStore.recordClear` pays clear + boss rewards (boss = Pangram-Hunt
  at a campaign capstone order; dailies deliberately excluded).
- `GameStore.recordWord` pays capped bonus-word rewards; the per-level
  meter persists in `LevelProgress.serenityBonusPaid`.
- `GameViewModel.useHintRevealCell` is the only hint charge/refund path.
- `EconomyTests` pins every constant and the pack-yield design-target
  range; `StoreTests` pins IAP amounts and pack value dominance.

### 5.3 Hashing

`FNV1a` (GameCore) is the project's single hash: wheel display order, the
per-launch hint-reveal seed, and daily-puzzle seeding all derive from it.
Its offset basis (`1_469_598_103_934_665_603`) is **intentionally** the
project's legacy, non-standard value — one digit short of the textbook
FNV-1a-64 basis — because shipped level generation already depends on the
exact seed values it produces. Do not "fix" it to the textbook constant.

---

## 6. Testing strategy

- **`Tests/GameCoreTests`** — pure unit tests for the submission pipeline,
  scoring, stir curve, doom bonus multiplier, first-letter hints, wheel display order,
  the save-state/store model, cosmetics, and `FNV1a`.
- **`Tests/LevelGenTests`** — the corpus/lexicons, wheel/scene/creature
  pickers, the crossword layout engine, `PackCatalog`, `Primes`,
  `DailyPuzzle`, `LevelGenError`, and a **solvability sweep**
  (`SolvabilitySweepTests`) that generates the first 50 campaign levels and
  asserts every grid slot is buildable from its wheel and every shared cell
  agrees across intersecting words.
- **`App/ZenWordOfDoomTests`** (Xcode app test target, `ZenWordOfDoomTests`)
  — app-layer coverage that needs `@testable import` of app types:
  `GameStore` persistence/economy behavior, `GameViewModel` flows, and
  bundled-visual asset lookup.

`swift test` runs the two package suites (152 tests as of this writing) and
needs no simulator; the app test target requires `xcodebuild test` against a
scheme/simulator.

---

### 6.1 Accessibility

`App/ZenWordOfDoom/AccessibilityPalette.swift` holds the fixed,
WCAG-contrast-verified color pairs used wherever a scheme-adaptive color
would be near-invisible (dark-mode wheel tiles, solved crossword letters),
plus Increase-Contrast variants for the marginal pairs; pinned by
`App/ZenWordOfDoomTests/WCAGContrastTests.swift`. `AccessibilityAnnouncer.swift`
defines the `AccessibilityAnnouncing` seam (`SystemAnnouncer` posts real
VoiceOver announcements; a null implementation keeps `GameViewModel` tests
deterministic) that `GameViewModel` calls at meaningful game events.
`A11yCardBackground.swift` provides the `a11yCardBackground(cornerRadius:)`
modifier shared by every material-backed card, swapping `.ultraThinMaterial`
for an opaque fill under Reduce Transparency. Grid VoiceOver descriptions
(`GridView.slotDescription`) are covered by
`App/ZenWordOfDoomTests/GridAccessibilityTests.swift`. Full conformance
summary and release checklist: [`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md).

## 7. History

This document originally proposed a SpriteKit-rendered scene layer, eight
SPM packages (`GameCore`, `WordEngine`, `LevelKit`, `InputKit`, `VoiceKit`,
`SceneKitFX`, `Audio`, `Persistence`), a DAWG-backed dictionary, and
SwiftData persistence. None of that shipped. The system that was actually
built is entirely SwiftUI (no SpriteKit), two SPM packages instead of eight,
`UITextChecker` for runtime validation with no bundled DAWG, and Codable
JSON persistence instead of SwiftData. The original proposal is preserved in
git history (see the pre-v0.2 commits) for anyone curious about the road not
taken; it should not be read as a description of the current app.
