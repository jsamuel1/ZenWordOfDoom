# Procedural level generation with on-device Foundation Models

**Status:** Design approved (brainstorm), pending implementation plan.
**Date:** 2026-06-30

## 1. Summary

Replace hand-authored levels with **fully procedural** level generation. Each
level's letter wheel, themed word pool, interlocking crossword grid, scene, and
creature are generated from a deterministic seed. The themed **word pool** is
produced by iOS 26's on-device **Foundation Models** when available, with a
deterministic generator as both the fallback (on non-Apple-Intelligence devices)
and the top-up that guarantees solvability. Levels are **stable** (a given level
index always yields the same puzzle) so the existing progression — linear
unlock, per-level best scores, bestiary — keeps working unchanged.

Words are themed **Zen** or **Doom** (Doom flavored after Cthulhu, Doom-the-game,
and Buffy), but **every word is a real dictionary word** — the theme only steers
*selection*, never invents proper nouns. Correctness is enforced by deterministic
filters, not by trusting the LLM.

On-device **image generation** to theme the visuals is explicitly **out of scope
for this spec** and will be designed separately; this design leaves a clean seam
for it.

## 2. Goals / non-goals

**Goals**
- Procedurally generate solvable, themed crossword levels from a seed.
- Use Foundation Models on-device to generate the themed word pool when available.
- Guarantee every placed word is real and buildable from the wheel.
- Keep levels stable/seeded so current progression is preserved.
- Work on every iOS 26.5 device (deterministic fallback when FM is unavailable).
- Keep the hard logic in a pure-Swift, headlessly testable package.

**Non-goals (this spec)**
- On-device image generation (separate follow-on spec; seam provided here).
- Networked / API LLMs (Claude Haiku etc.) — on-device only.
- Endless or daily-puzzle modes — campaign of stable seeded levels only.
- Cross-device-identical levels on Apple-Intelligence devices (FM output is
  cached per device; acceptable for single-player).

## 3. Key decisions (from brainstorm)

1. **Where:** runtime, on-device, iOS 26 Foundation Models (text model).
2. **Format:** runtime crossword build — generate a themed word pool, then lay
   out an interlocking grid.
3. **Authoring:** fully procedural — wheel, words, grid, scene, creature all
   generated from `(theme, band, seedIndex)`.
4. **Fallback:** deterministic themed generator (anagram search over a bundled,
   pre-verified themed seed list).
5. **Identity:** stable seeded levels; FM word pool cached per level.
6. **FM role (Approach A):** FM drives the canonical words, cached per level;
   deterministic top-up guarantees a solvable grid.

## 4. Architecture & module boundaries

Foundation Models and `UITextChecker` are iOS-only, so they live in the **app
target**. All deterministic, testable logic lives in a new pure-Swift package
target **`LevelGen`** (alongside `GameCore`, `WordEngine`, `LevelKit`).

```
LevelGen (pure Swift, headless-tested)
  Theme                     // .zen / .doom
  LevelSeed                 // theme, band, index → stable id
  GeneratedLevel            // wheel, slots, sceneID, creatureID, theme, id
  ThemedWordProvider        // protocol: async words(forWheel:theme:limit:)
  SeedListWordProvider      // deterministic anagram search over bundled seed list
  ThemedSeedList            // bundled, pre-verified real words tagged by theme
  WheelPicker               // seeded themed base-word → wheel letters
  CrosswordLayoutEngine     // validated words → interlocking, solvable grid (seeded)
  SceneCreaturePicker       // seeded scene/creature assignment per theme
  ProceduralLevelLibrary    // seeded ordered sequence of GeneratedLevel ids

App target (iOS-only)
  FoundationModelsWordProvider   // ThemedWordProvider via FM (LanguageModelSession)
  SystemDictionary               // existing — UITextChecker real-word filter
  GeneratedLevelCache            // persists generated levels (JSON, App Support)
  LevelGenerationCoordinator     // orchestrates: availability → provider → filter → layout → cache
  SceneVisualProvider            // seam: id → visual (today: procedural shader/art)
```

The pure `LevelGen` never imports UIKit/FoundationModels. The app injects a
`WordValidating` (the existing `SystemDictionary`) to filter FM output before it
reaches the pure layout engine, so the package stays platform-agnostic.

## 5. Generation pipeline

Input: `LevelSeed(theme, band, index)`. All steps seeded by `index` (+ theme) so
output is reproducible per id.

1. **Wheel** — `WheelPicker` deterministically chooses a themed *base word* of
   the band's length (5–9, via existing `DifficultyBand`) from `ThemedSeedList`;
   its letters become the wheel. A base word guarantees a rich anagram set.
2. **Word pool**
   - **Primary (FM):** `FoundationModelsWordProvider` prompts FM with the wheel
     letters + theme and requests candidate words (guided/structured output).
   - **Filter (app):** keep only words that are **buildable**
     (`LetterMultiset.canBuild`) **and real** (`SystemDictionary`/UITextChecker),
     de-duplicated, length ≥ `GameEngine.minWordLength`.
   - **Top-up (deterministic):** if fewer than the minimum required grid words,
     `SeedListWordProvider` adds seeded anagram matches from the seed list
     (already real) until the minimum is met.
3. **Grid** — `CrosswordLayoutEngine` interlocks a seeded subset of the validated
   pool into a connected, fillable crossword (`GridSlot`s). Retries with a
   simpler layout if needed; never emits an unsolvable grid.
4. **Scene/creature** — `SceneCreaturePicker` assigns a scene + creature (seeded)
   from the existing asset pools for the theme, preserving reveal + bestiary.
5. **Result** — a `GeneratedLevel` with stable `id`. The app caches it via
   `GeneratedLevelCache`.

## 6. Theme model

- `Theme` ∈ {`zen`, `doom`}. Assigned per pack (default: Zen and Doom packs
  alternate; band escalates with depth).
- Theme steers **selection among real words only**:
  - **Doom** vocabulary evokes Cthulhu / Doom-the-game / Buffy using real words
    (e.g. ELDER, ABYSS, CRYPT, DREAD, FIEND, SLAY, STAKE, FANG, IMP, RITE, OMEN,
    TOMB, SHADE, GRAVE, HEX).
  - **Zen** vocabulary is calm (e.g. CALM, STILL, LOTUS, BREATH, GRACE, FLOW,
    PEACE, MIND).
- The franchise flavor lives in (a) the **FM prompt** and (b) how the
  **`ThemedSeedList`** is curated. The buildable + dictionary filters enforce
  "all real words" regardless of what FM proposes. The seed list is verified
  100% real by a unit test (see §10).

## 7. Stability, caching & progression

- **Stable id:** `"<theme>-<band>-<index>"` (or similar). Wheel, grid, scene,
  creature derive deterministically from it. FM word pool is generated **once**
  and cached under that id.
- **Cache:** `GeneratedLevelCache` persists generated levels as JSON in
  Application Support (next to `GameStore`). Replays read the cache; a miss
  regenerates (FM if available, else deterministic).
- **Progression:** `ProceduralLevelLibrary` supplies a deterministically ordered,
  lazily-extended sequence of level ids. `LevelLibrary.orderedLevelIDs()` is
  reimplemented on top of it (returns ids up to a horizon ahead of the player's
  furthest unlock). Existing `GameStore.isUnlocked` / `nextUnclearedLevelID` /
  best scores / bestiary keep working because ids are stable.
- The bundled **`ThemedSeedList`** replaces `SampleWords.canonical` as the word
  corpus. `SampleWords` may be retired or reduced to test fixtures.

## 8. Availability & latency UX

- Check `SystemLanguageModel.default.availability`: `.available` → FM provider;
  otherwise (`deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`)
  → `SeedListWordProvider`.
- FM runs behind a **timeout**; on error/stall/empty, fall back to deterministic
  so a level always starts.
- Show a brief themed loader while generating ("composing the garden…" /
  "stirring the doom…"). **Pre-generate the next level** in the background to
  hide latency on the common path.

## 9. Validation & solvability (correctness backbone)

Invariants enforced and tested:
- Every word placed in a grid is **buildable** from the wheel and **real**.
- Each level has at least the minimum number of grid words (top-up guarantees).
- The grid is **connected and fillable** (a valid crossword).
- Same seed ⇒ identical level (determinism).
The LLM is never trusted for correctness — only for themed candidate words.

## 10. Testing

`LevelGen` is pure → extensive headless unit tests:
- Determinism: same seed ⇒ same `GeneratedLevel`.
- Solvability/connectivity invariants over many seeds and bands.
- Buildability of every placed word.
- `ThemedSeedList` is 100% real words (the project already validates words via a
  dictionary in tests).
- `CrosswordLayoutEngine` edge cases (sparse pools, forced fallback layout).

`ThemedWordProvider` is a protocol → FM is mockable. The iOS-only
`FoundationModelsWordProvider` and `SystemDictionary` filtering get light
app-target tests (and manual simulator/device verification, since FM needs the
runtime).

## 11. Image-generation seam (future spec)

Scene/creature visuals resolve through a new **`SceneVisualProvider`** (id →
visual). Today it returns the existing procedural shader / bundled art. A future
on-device image-generation source (Image Playground / bundled Core ML diffusion)
plugs in there — with per-level caching analogous to the word-pool cache — with
no changes to generation or gameplay.

## 12. Risks & open questions

- **Grid layout is the hardest piece** for fully-procedural content; may need
  iteration to produce satisfying crosswords across all band sizes.
- **FM output quality/latency** on-device is variable; the buildable+dictionary
  filter plus deterministic top-up de-risk correctness, but FM may often
  contribute few words on small wheels — acceptable (it enriches; deterministic
  guarantees the floor).
- **Migration:** retiring `levels.json` / `LevelData` / `SampleWords` touches
  existing tests and `LevelLibrary`; the plan must update these.
- **Theme cadence** (alternating packs vs per-level) is a tunable default, not a
  hard requirement.
