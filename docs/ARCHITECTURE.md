# Zen Word of Doom — Technical Architecture

Companion to [`SPEC.md`](SPEC.md). Describes the proposed technical design:
stack, module boundaries, data formats, and the key subsystems (word
validation, input resolution, the reveal engine).

---

## 1. Stack & rationale

| Concern | Choice | Why |
| --- | --- | --- |
| Language | **Swift 5.9+** | Native, performant, first-class on iOS |
| Min OS | **iOS 17+** | Modern SwiftUI/Observation, on-device speech maturity |
| App chrome / menus / HUD | **SwiftUI** | Declarative, fast iteration, accessibility built-in |
| Game scene (wheel, grid, trace, FX) | **SpriteKit** | 2D node graph, physics-lite, shaders, great for the wheel + reveal animations; embedded via `SpriteView` |
| Reveal / scene FX | **SpriteKit + `SKShader` / Core Image** | Mask-based creature reveal driven by a single `stir` uniform |
| Voice | **Speech (`SFSpeechRecognizer`)** + **AVFoundation** | On-device recognition, mic capture |
| Dictionary | **Bundled DAWG/trie** | O(word length) membership + buildability checks, small footprint |
| Persistence | **SwiftData** (or Codable + files) | Progress, settings, stats; CloudKit-syncable |
| Packaging | **Swift Package Manager** | Modular targets, no CocoaPods needed |
| Audio | **AVAudioEngine** | Layered ambient + reactive Doom stinger bus |

> SpriteKit (not full SceneKit/RealityKit/Metal) is the sweet spot: the game is
> 2D, art-driven, and the reveal is a shader/mask effect — SpriteKit handles all
> of it with far less complexity than a custom Metal pipeline, while SwiftUI
> owns navigation and menus.

---

## 2. Module layout (SPM targets)

```
ZenWordOfDoom/                      # App target (SwiftUI @main, app lifecycle)
Packages/
  GameCore/        # Pure Swift, no UIKit: rules, models, scoring, grid gen
  WordEngine/      # Dictionary (DAWG), validation, buildability, anagram search
  LevelKit/        # Level data models + JSON loading + (optional) generator
  InputKit/        # Tile-sequence resolution from swipe/tap; shared model
  VoiceKit/        # Speech recognition wrapper, word-candidate matching
  SceneKitFX/      # SpriteKit scenes: wheel, grid, trace overlay, reveal engine
  Audio/           # AVAudioEngine ambient + reactive bus
  Persistence/     # SwiftData stores: progress, settings, bestiary, stats
```

`GameCore` and `WordEngine` are **pure, fully unit-testable** Swift with no
Apple-UI dependencies. UI/scene/voice modules depend on them, never the
reverse.

---

## 3. Core domain model (GameCore)

```swift
struct LetterTile: Identifiable, Equatable {
    let id: Int          // stable per-level tile identity (handles duplicates)
    let letter: Character
}

struct Wheel {
    let tiles: [LetterTile]          // 5...9 tiles
    var size: Int { tiles.count }    // == max word length N
}

struct GridSlot: Identifiable {
    let id: Int
    let answer: String               // hidden until found
    let cells: [GridCoord]           // ordered cells this word occupies
    let direction: Direction         // .across / .down
}

struct GridCell {
    let coord: GridCoord
    var filledLetter: Character?     // nil until a crossing word fills it
}

struct Level {
    let id: String
    let wheel: Wheel
    let grid: [GridSlot]
    let cells: [GridCoord: GridCell]
    let sceneID: String
    let creatureID: String
    let band: DifficultyBand         // derived from wheel.size
}

enum SubmissionResult {
    case filledSlots([GridSlot.ID])  // matched one+ grid answers
    case bonusWord(String)           // valid, not in grid
    case invalid(reason: InvalidReason)
}
```

### 3.1 Word submission pipeline

```
Tile sequence ([LetterTile.id])
  → resolve to word string (InputKit)
  → length 3...N ?                         (GameCore rule)
  → buildable from wheel multiset ?         (always true for swipe/tap;
                                             re-checked for voice)
  → valid dictionary word ?                 (WordEngine)
  → matches an unfilled grid answer ?       (GameCore)
        yes → SubmissionResult.filledSlots  → fill cells, bump stir
        no  → SubmissionResult.bonusWord    → reward, bump stir (less)
  → else SubmissionResult.invalid
```

The **same pipeline** serves all three input methods. Swipe/tap deliver tile
IDs directly. Voice delivers a *string*, which `VoiceKit` maps back to a tile
sequence by greedily matching against the wheel multiset before entering the
pipeline.

---

## 4. WordEngine

- **Storage:** a **DAWG** (directed acyclic word graph) or compressed trie built
  offline from the curated word list and bundled as a binary asset. Gives:
  - `contains(word) -> Bool` in O(len).
  - Prefix walks for the (optional) level generator and anagram search.
- **Buildability:** `canBuild(word, from: multiset) -> Bool` via letter-count
  subtraction; cheap and independent of the DAWG.
- **Anagram/sub-anagram search** (for generation & "all bonus words" stats):
  DFS over the DAWG constrained by the available letter multiset.

```swift
protocol Dictionary {
    func contains(_ word: String) -> Bool
    func words(buildableFrom multiset: LetterMultiset, minLength: Int) -> [String]
}
```

Word list selection (license) is an open question — see SPEC §13.

---

## 5. InputKit — unifying the three inputs

A single state machine produces an ordered tile selection; the rendering layer
(SpriteKit) feeds it raw gestures.

```swift
enum TileInputEvent {
    case begin(tileID: Int)      // touch-down on a tile (swipe) or tap
    case extend(tileID: Int)     // drag entered a tile / next tap
    case backtrack               // drag retreated / deselect last
    case submit                  // finger lifted / submit tapped
    case cancel                  // clear
}

final class WordBuilder {
    private(set) var selection: [Int] = []   // tile IDs, in order
    func apply(_ event: TileInputEvent) -> [Int]? // returns sequence on .submit
}
```

- **Swipe** and **tap** differ only in how gestures map to `extend`/`submit`.
- **Voice** bypasses gestures: `VoiceKit` yields a candidate tile sequence that
  is injected as if typed, then `.submit`.

---

## 6. VoiceKit

```swift
final class VoiceInput {
    func authorize() async -> Bool                  // mic + speech permission
    func recognizeOnce() async throws -> [String]   // ranked candidate strings
}
```

- Uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` when
  `supportsOnDeviceRecognition`. Falls back gracefully (or stays disabled) if
  unsupported.
- Captures a short utterance via `AVAudioEngine`, returns ranked transcriptions.
- **Candidate resolution:** for each transcription, normalize → check
  `canBuild` + `contains`; pick the highest-ranked candidate that is buildable
  and valid (preferring grid answers). Map it to tile IDs and submit.
- Privacy: on-device only by default; nothing persisted or transmitted.

---

## 7. The reveal engine (SceneKitFX)

The Zen scene and its hidden creature are rendered as layered `SKSpriteNode`s
with a shared **`stir` uniform** (0…1) driving a fragment shader / Core Image
chain:

- **Zen base layer** — always visible painterly scene.
- **Creature mask layer** — the creature painted into the scene; its alpha /
  contrast / glow ramps with `stir`.
- **Atmosphere** — desaturation→red shift, vignette, shadow deepening, subtle
  domain-warp near the creature, all parameterized by `stir`.

```swift
final class RevealController {
    private(set) var stir: Double = 0     // 0 calm ... 1 fully revealed
    func registerWord(scoreWeight: Double)        // small increment
    func completeLevel()                          // ramp to 1 for ~1.5s, then ease back
    var reducedDoom: Bool                         // caps stir, mutes stingers
}
```

- `registerWord` nudges `stir` up; `completeLevel` drives the held reveal then
  the calming exhale.
- **Reduced-motion / Reduced-Doom** clamps the max `stir` and swaps reactive
  audio for ambient-only.

Audio mirrors this: `Audio` exposes an ambient bus (always) and a reactive bus
(low growl/heartbeat) whose gain tracks `stir`.

---

## 8. Level data format (LevelKit)

Levels are **data, not code** — authored or generated, loaded from bundled
JSON. Example:

```json
{
  "id": "garden-003",
  "band": "medium",
  "wheel": ["S", "T", "O", "N", "E", "D"],
  "scene": "sand-garden",
  "creature": "rock-oni",
  "grid": {
    "size": [7, 7],
    "slots": [
      { "id": 0, "answer": "STONE",  "row": 1, "col": 1, "dir": "across" },
      { "id": 1, "answer": "NODE",   "row": 1, "col": 5, "dir": "down" },
      { "id": 2, "answer": "DOTS",   "row": 3, "col": 1, "dir": "across" }
    ]
  }
}
```

- The loader validates: every answer is buildable from `wheel`; wheel multiset
  equals the union of answers; grid is connected; at least one pangram word for
  bands 7+.
- A **generator** (optional, offline tool target) can produce candidate levels:
  pick a seed word set from the DAWG, lay out an interlocking grid, derive the
  wheel, validate. Generation runs offline; the app ships static validated
  levels plus daily seeds.

---

## 9. Persistence (Persistence)

SwiftData models (CloudKit-syncable):

- `PlayerProfile` — serenity currency, settings (reduced doom, first-letter
  hints, voice enabled), unlocked scenes.
- `LevelProgress` — per level: cleared, best score, bonus words found, no-hint
  flag, stir peak.
- `BestiaryEntry` — creatures revealed.
- `Stats` — streaks, longest word, pangrams, totals.

---

## 10. Testing strategy

- **GameCore / WordEngine:** pure unit tests — submission pipeline, buildability,
  scoring, grid-fill, dictionary membership, generator validity invariants.
- **LevelKit:** every bundled level passes the validation invariants (a test
  iterates all level files).
- **InputKit:** state-machine tests for swipe/tap/backtrack/submit sequences.
- **VoiceKit:** candidate-resolution logic tested against fixed transcription
  fixtures (no live mic in tests).
- **UI / Scene:** snapshot tests for key states; reveal engine driven by
  setting `stir` directly.

---

## 11. Suggested build order

See [`ROADMAP.md`](ROADMAP.md). In short: prove the word-game core (wheel +
grid + swipe/tap + dictionary) headless-testable first, then layer scene/reveal,
then voice, then meta/progression.
