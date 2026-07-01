# Zen Word of Doom — v0.2 "Sound, Reveal, Store & Scene Coupling" Design

- **Date:** 2026-07-01
- **Status:** Design (approved for planning)
- **Supersedes:** nothing; extends [`SPEC.md`](../../SPEC.md),
  [`2026-06-30-procedural-level-generation-design.md`](2026-06-30-procedural-level-generation-design.md),
  and [`2026-06-30-on-device-image-generation-design.md`](2026-06-30-on-device-image-generation-design.md).

## 1. Motivation

The v0.1 line shipped a well-architected engine but a thin *experience*: the
curated scene/creature art never appears in the play loop (the in-level
background is a procedural gradient + blob), there is no audio at all (the
`soundEnabled` setting is a dead toggle), the meta is an infinite difficulty
treadmill with no identity or payoff, the serenity economy has no sink, and
there is no monetization. This design closes those gaps and pulls two mechanics
back toward the original [`SPEC.md`](../../SPEC.md): scene-coupled words and a
shuffleable wheel.

## 2. Goals

1. **Real art on screen, revealed slowly** — bundled scene art as the level
   background; the paired creature surfaces with `stir`.
2. **Adaptive generative audio** — a note-driven engine whose mood tracks
   `stir`/theme; the "reactive doom bus" the original spec wanted.
3. **A meta spine** — named packs over the infinite generator, a level-clear
   celebration, a found-words tray, streaks/stats.
4. **Monetization** — premium demo→unlock, serenity IAP packs, a serenity
   cosmetic sink, and free-tier cut-scene ads gated behind a Continue button.
5. **Scene-coupled words** — the words you spell relate to the scene revealed.
6. **Shuffleable wheel** — randomized tile positions + a re-randomize button.

## 3. Non-goals (v0.2)

- iPad/Mac layouts, online multiplayer, user-generated levels, localization
  (unchanged from [`SPEC.md`](../../SPEC.md) §12).
- Finite hand-authored campaign — we keep the infinite generator (per the
  "named milestones" decision) rather than shipping a fixed level set.
- Server-side receipt validation — StoreKit 2 on-device signed transactions are
  the secure default; no backend.
- Personalized ad targeting / cross-app tracking beyond what a non-personalized
  ad unit requires.

## 4. Workstreams

Each workstream is independently shippable behind its own tests. Suggested
build order: F → A → B → C → D (F and A share the reveal path; D depends on C's
pack/paywall boundary).

---

### A. Real art + slow reveal in gameplay

**Today:** `GamePlayView` renders `RevealBackgroundView` — a fully procedural
gradient with a 9-lobe silhouette. The 26 bundled scene/creature JPEGs
(`Assets.xcassets/scene-*`, `creature-*`) appear only on the menu, bestiary, and
faintly behind cut scenes. The `SceneCreaturePicker` slugs already map 1:1 to
bundled asset names via `BundledVisuals` (`still-pond` → `scene-still-pond`,
`koi-spirit` → `creature-koi-spirit`).

**Change:** a new `SceneRevealView` (replacing `RevealBackgroundView` in the
play screen) composites two image layers plus a stir-driven treatment:

1. **Base (calm):** the bundled scene image for `level.sceneID`, full opacity.
2. **Creature (hidden):** the bundled creature image for `level.creatureID`,
   composited above the scene. Its `opacity`, `scale`, and `saturation` are
   driven by `stir` via a `smoothstep` so it is invisible near 0 and fully
   present near 1.
3. **Treatment:** a stir-driven darkening + vignette + slight red-shift over the
   whole scene (reuse the existing palette/vignette math).

- **Completion beat:** on `isComplete` (`stir` is already forced to 1), hold the
  full creature ~1.5s, then exhale (animate `stir`→calm) as the clear resolves.
- **Fallback chain (unchanged philosophy):** scene/creature image → if a slug
  has no bundled asset, fall through to the **existing procedural renderer**
  (kept as `ProceduralRevealLayer`). This preserves coverage for future
  generator slugs.
- **Accessibility:** `reducedDoom` caps creature opacity + treatment intensity;
  `reducedMotion` freezes to a static reveal. Both are already plumbed into the
  view inputs.
- **Bestiary rule unchanged:** only Doom levels catalog their creature; Zen
  levels reveal a calm guardian that is not recorded.

**Wheel shuffle (part of the play UI):**
- The wheel renders tiles in a **display order** distinct from `wheel.tiles`
  array order. Initial order is a **seeded shuffle** (stable per level, not
  alphabetical/canonical).
- A **Shuffle button** re-rolls the display order on demand (cosmetic only;
  never mutates the letter multiset), with a tap haptic. Selection and the
  connecting trail already key off tile IDs, so positions can move freely
  mid-level without affecting an in-progress word (shuffle cancels any
  in-progress selection first).
- `WheelView` gains a `displayOrder: [Int]` (tile-id ordering) input; the owning
  view model owns and re-rolls it.

**Testing:** snapshot-free — assert `SceneRevealView` selects the correct asset
names for given ids and falls back when a slug is unknown; assert shuffle is a
permutation of the same tile-id set (letters preserved) and that it clears any
active selection.

---

### B. Generative adaptive audio (AudioKit)

**Dependency:** add `AudioKit` (SPM). New `Sound` module, protocol-fronted:

```
protocol SoundEngine {         // implemented by AudioKitSoundEngine + NullSoundEngine (tests/CI)
    func start()
    func setMood(theme: Theme, stir: Double)   // drives the music morph
    func play(_ cue: SoundCue)                  // one-shot SFX
    func setEnabled(music: Bool, sfx: Bool)
    func stop()
}
```

- **Music (generative):** a note-driven engine. A `MusicalPalette` per mood
  defines `scale`, `drone`, and `timbre`:
  - **Zen** — pentatonic melody, singing-bowl/low sine drone, soft attack.
  - **Doom** — minor/tritone intervals, low growl drone, harder timbre.
  - **Crossover** — live interpolation between the two palettes as a function of
    `stir` (and hard-selected base by level `theme`). This is the single
    reactive signal the original spec called the "doom bus": **audio and the
    visual reveal share `stir`.**
  - Notes are scheduled on a slow generative clock (seeded per level for
    reproducibility), so the bed is "infinite" without loops to license.
- **SFX (one-shot, bundled `.caf`):** `SoundCue` cases — `wordLand` (chime),
  `invalid` (soft buzz), `bonus` (sparkle), `hintReveal`, `levelClear` (the
  payoff), `cutScenePopout` (sting). Authored via ElevenLabs Text-to-SFX (paid
  tier includes royalty-free commercial license) or hand-made (Bfxr/GarageBand).
- **Settings:** wire the currently-dead `soundEnabled` toggle to gate all audio;
  add a **Music / SFX** split. `reducedDoom` softens or omits the growl and
  pop-out sting.
- **Lifecycle:** engine started on entering a level/cut scene, `setMood` called
  from the view model whenever `stir` changes, stopped on disappear. The app
  target owns a single shared engine injected via environment (like
  `VisualProviderBox`).

**Testing:** `NullSoundEngine` (no-op) is the default in tests and CI so nothing
requires AudioKit hardware. Unit-test `MusicalPalette` interpolation
(scale/timbre at stir 0, 0.5, 1) and that the view model emits `setMood` on stir
changes and the right `SoundCue` per submission result. AudioKit itself is not
unit-tested.

---

### C. Meta spine — named packs (milestone overlay)

Keep `ProceduralLevelLibrary`'s infinite ordering; overlay identity.

- **`Pack` concept:** every `packSize` (10) levels is a named pack with a
  `title`, short flavor line, and a **signature creature** guaranteed at the
  pack's capstone (level 10 of the pack). New `PackCatalog` (data) maps pack
  index → name/flavor/signature; the generator pins the capstone level's
  `creatureID` to the signature for that pack.
- **Pack banner:** shown on entering the first level of a pack (title + flavor),
  brief and skippable.
- **Level-clear celebration:** a dedicated completion overlay — score count-up,
  serenity tally, and a **"NEW CREATURE"** fanfare (audio `levelClear` + success
  haptic) when a Doom capstone is first revealed. This is the missing dopamine
  beat; replaces the silent "The garden settles…" transition.
- **Found-words tray:** show `foundGrid / totalGrid` and a scrollable list of
  bonus words on the play screen (data already in `engine.bonusWords`).
- **Streaks & stats:** a Stats screen surfacing `GameStats` (levels cleared,
  creatures revealed, longest word, pangrams) + a daily streak counter
  (new: last-played date + streak in `SaveState`).
- **First-letter hints:** wire the currently-dead `firstLetterHints` toggle to
  pre-reveal each slot's first cell at level start (per SPEC §7 casual mode).

**Testing:** `PackCatalog` mapping (order→pack, capstone detection, signature
pinning) and streak update rules (increment same-day-noop, break on gap) are
pure and unit-tested.

---

### D. Monetization

**StoreKit 2, on-device signed transactions (secure default; no backend).**
New `StoreService` protocol with a real (`StoreKitStoreService`) and a mock
(`MockStoreService`) implementation.

- **Premium unlock (non-consumable):** the game is free through the **end of
  pack 1 (level 10)**. Entering level 11+ without premium shows a **paywall**.
  Entitlement is derived from StoreKit's current entitlements and mirrored into
  `SaveState` for offline reads. **Restore Purchases** in Settings.
- **Serenity packs (consumable):** three tiers (e.g. Small/Medium/Large).
  Purchases credit serenity via the existing `GameStore.addSerenity`. Serenity
  remains fully earnable; it only buys hints + cosmetics (**no pay-to-win**).
- **Serenity sink — cosmetics:** unlock alternate **scene palettes** and/or
  **cut-scene poem sets** with earned *or* bought serenity, giving the currency
  a reason to accumulate. Owned cosmetics persist in `SaveState`.
- **Cut-scene ads (free tier only):**
  - On the cut scene, free-tier players get an interstitial; the **Continue
    button stays hidden until the ad completes** (or, if no ad fills within a
    short timeout, a fallback timed delay elapses — the player is never
    trapped). Premium players skip ads entirely and see Continue immediately
    (current behavior).
  - **Provider (decided):** **AdMob with a non-personalized ad unit** — the
    least-invasive option consistent with the calm/no-dark-pattern brand.
  - **Privacy/rating impact (must land with this workstream):** an ad SDK is a
    third-party dependency that collects data. This requires updating the
    **App Privacy nutrition labels** (data used to track / linked to identity as
    applicable), an **App Tracking Transparency** prompt only if personalized
    (non-personalized avoids ATT), and a review of the **age rating**. The v1
    "no third-party tracking SDKs" pledge in [`SPEC.md`](../../SPEC.md) §10 is
    explicitly revised here for the free tier.

**Testing:** `MockStoreService` drives paywall gating, entitlement mirroring,
serenity crediting, and cosmetic unlock/spend as pure unit tests. StoreKit and
AdMob live paths are manual/QA, not CI.

---

### E. Cross-cutting

- **Settings additions:** Music/SFX toggles, Restore Purchases, cosmetics
  picker.
- **Privacy & rating:** update `Info.plist`, App Privacy labels, and age rating
  for the ad SDK (see D).
- **Injection:** `SoundEngine`, `StoreService`, and cosmetics state injected via
  environment objects, mirroring the existing `VisualProviderBox`/`LevelService`
  pattern, so the pure cores stay decoupled and testable.

---

### F. Scene-coupled word selection (generation-order inversion)

**Today (`ProceduralGenerator`):** letters first → words → scene picked
*independently*. The words you spell have no relationship to the scene revealed.

**Change:** invert to scene-first, aligning with [`SPEC.md`](../../SPEC.md) §3
(the wheel *is* the letter-multiset of the target words):

1. **Pick scene/creature** from the seed (`SceneCreaturePicker`, unchanged).
2. **Gather scene-related target words** from a new **`SceneLexicon`** — data
   mapping each `sceneID` to associated real words (e.g. `still-pond` → POND,
   KOI, REED, CALM, LILY, MIST, CARP…; `ember-catacomb` → EMBER, ASH, TOMB,
   BONE, CRYPT…). Words are filtered to the band's max length.
3. **Choose a key word** sized to the band's wheel length (5–9) — preferring a
   scene-related word of exactly that length; if none exists, fall back to a
   themed/common word of that length. The **wheel letters are that key word's
   multiset** (then shuffled per workstream A).
4. **Build the grid** from sub-anagrams of the wheel, **preferring
   scene-related then themed then common** words, so required answers feel tied
   to the revealed scene. Existing solvability guarantees hold because every
   answer is a sub-anagram of the wheel, and the wheel derives from a real word.

**Interfaces:** `SceneLexicon` is pure data (Swift-embedded or a bundled
resource, like `ThemeLexicon`). `WheelPicker`'s role narrows: given a chosen key
word it produces the tiles; the *choice* of key word moves into the generator so
it can be scene-aware. `ThemedWordProvider` still supplies the broader
buildable pool for bonus words and grid fill.

**Determinism & fallback:** everything stays seed-driven. If a scene has too few
lexicon words to form a wheel/grid on a given seed, fall back to the current
theme-word path (never produce an empty or unsolvable grid — the existing
`precondition`/`minInterestingSlots` safety net remains).

**Testing:** `SceneLexicon` coverage (every scene slug has ≥ a minimum word
count across bands); generator produces a wheel derived from a real key word;
grid answers are all sub-anagrams of the wheel; a scene-poor edge case falls
back without crashing; determinism (same seed → same level) preserved.

## 5. Data model changes (summary)

- `SaveState`: `premiumUnlocked: Bool`, `ownedCosmetics: Set<String>`,
  `lastPlayedDate` + `streak`, (serenity already present).
- New pure types: `SceneLexicon`, `PackCatalog`, `MusicalPalette`, `SoundCue`,
  protocols `SoundEngine` / `StoreService`.
- `WheelView`: `displayOrder: [Int]`; `GameViewModel`: owns display order +
  shuffle, emits `setMood`/`SoundCue`.

## 6. Sequencing

1. **F** (scene-coupled words) + **A-wheel-shuffle** — pure generator + small UI;
   fully unit-testable, no new deps.
2. **A-reveal** — swap the play-screen background to real art.
3. **B** (audio) — new dep + module; `NullSoundEngine` keeps CI green.
4. **C** (packs, celebration, tray, stats, first-letter hints).
5. **D** (StoreKit unlock + serenity packs + cosmetics + AdMob ads + privacy).

## 7. Open questions

1. **SceneLexicon authoring** — hand-curate per-scene word lists, or generate
   them once (Foundation Models / offline) and bundle? (Lean: hand-curate a
   small high-quality core per scene; it is content, not code.)
2. **Serenity pack price points & sizes** — set during D.
3. **Cosmetic scope for v0.2** — palettes only, or palettes + poem sets? (Lean:
   palettes first.)
4. **AdMob mediation** — single network vs. mediation; personalized opt-in
   later? (Default: single, non-personalized.)

## 8. Testing philosophy (unchanged)

Pure cores (`GameCore`, `LevelGen`, new `SceneLexicon`/`PackCatalog`/
`MusicalPalette`/store gating) stay UI-free and fully unit-tested. Hardware/
service paths (AudioKit, StoreKit, AdMob) sit behind protocols with null/mock
implementations so CI needs no entitlements or devices.
