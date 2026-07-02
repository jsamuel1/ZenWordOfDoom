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
4. **Monetization** — free-to-play and **ad-supported after pack 1** (cut-scene
   ads only, gated behind the Continue button); a **$4.99 remove-ads premium**;
   serenity IAP packs; and a serenity cosmetic sink (**the Shrine**). No
   content is ever paywalled.
5. **Scene-coupled words** — the words you spell relate to the scene revealed.
6. **Shuffleable wheel** — randomized tile positions + a re-randomize button.
7. **Boss capstones** — each pack's last level (10) is a harder, non-crossword
   **Pangram Hunt** where the signature creature is revealed.

## 3. Non-goals (v0.2)

- iPad/Mac layouts, online multiplayer, user-generated levels, localization
  (unchanged from [`SPEC.md`](../../SPEC.md) §12).
- Finite hand-authored campaign — we keep the infinite generator (per the
  "named milestones" decision) rather than shipping a fixed level set.
- Server-side receipt validation — StoreKit 2 on-device signed transactions are
  the secure default; no backend.
- Ad-network mediation (single network only).

## 4. Workstreams

Each workstream is independently shippable behind its own tests. Suggested
build order: F → A → B → C → D (F and A share the reveal path; D depends on C's
pack boundary — it defines where the ad-free grace period ends).

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

- **Model (revised 2026-07-02): free-to-play, ad-supported, pay to remove
  ads.** All levels are free forever — there is **no content paywall**. Pack 1
  (levels 1–10) is an ad-free grace period; from level 11 on, free players see
  a cut-scene ad after each level (below). This replaces the earlier
  demo→unlock design.
- **Premium "Remove Ads" (non-consumable), $4.99:** removes all ads,
  permanently. Offered unobtrusively: a "Remove ads · $4.99" affordance on the
  ad slot itself, plus Settings and menu entries — never a gate. **No Family
  Sharing.** Entitlement is derived from StoreKit's current entitlements and
  mirrored into `SaveState.premiumUnlocked` for offline reads; a refund
  observed via `Transaction.updates` flips it back. **Restore Purchases** in
  Settings. Consumable purchases record processed transaction IDs in
  `SaveState` so replayed unfinished transactions can't double-credit.
- **Serenity packs (consumables), three tiers:** `$0.99 → 10`, `$1.99 → 25`,
  `$3.99 → 50` serenity (small-number values consistent with the existing
  economy: hints cost 5, clears earn ~10–15). Purchases credit serenity via the
  existing `GameStore.addSerenity`. Serenity remains fully earnable; it only buys
  hints + cosmetics (**no pay-to-win**).
- **Serenity sink — the Shrine (cosmetics: palettes + poem sets):** a dedicated
  menu item (between Bestiary and Stats) where the player browses, previews,
  unlocks (with earned *or* bought serenity), and equips alternate **scene
  palettes** and **cut-scene poem sets** — a shop that doesn't feel like a
  shop, and the reason serenity accumulates. Priced ~25–75 serenity each to sit
  within the small-number economy. Owned cosmetics persist in `SaveState`
  (`ownedCosmetics`); the equipped choice applies immediately.
- **Cut-scene ads (free players, level 11+ only):**
  - Ads appear **only in the between-level cut scenes**, never mid-puzzle. The
    **Continue button stays hidden until the ad completes** (or, if no ad
    fills within a short timeout, a fallback timed delay elapses — the player
    is never trapped). Pack 1 (levels 1–10) is always ad-free; premium players
    never see ads and get Continue immediately (current behavior).
  - **`AdService` protocol seam:** the ad slot + Continue gating is built
    against an `AdService` protocol first, with a Null/house-placeholder
    implementation (a timed, skip-safe slot) so the whole flow is testable in
    the simulator without the SDK; the AdMob-backed implementation drops in
    behind the protocol as the final step.
  - **Provider (decided):** **AdMob, single network** (no mediation).
    **Personalized ads by default with a user opt-out** — a "Personalized ads"
    toggle in Settings; when off, the app requests non-personalized ads.
  - **Privacy/rating impact (must land with this workstream):** an ad SDK is a
    third-party dependency that collects data. Because personalization is on by
    default, an **App Tracking Transparency** prompt **is required**; if the user
    denies ATT (or toggles personalization off), the app serves non-personalized
    ads. This also requires updating the **App Privacy nutrition labels** (data
    used to track / linked to identity) and a review of the **age rating**. The
    v1 "no third-party tracking SDKs" pledge in [`SPEC.md`](../../SPEC.md) §10 is
    explicitly revised here for the free tier.

**Testing:** `MockStoreService` drives paywall gating, entitlement mirroring,
serenity crediting, and cosmetic unlock/spend as pure unit tests. StoreKit and
AdMob live paths are manual/QA, not CI.

---

### E. Cross-cutting

- **Settings additions:** Music/SFX toggles, Restore Purchases, cosmetics
  picker, and (free tier) a **Personalized ads** opt-out toggle.
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
   BONE, CRYPT…). Words are filtered to the band's max length. **Authoring: the
   per-scene lists are generated once, offline, and bundled** as a resource
   (e.g. a build-time script prompting Foundation Models / a word source per
   scene slug, then hand-reviewed for quality and safety) — not generated at
   runtime. A generation script + a checked-in `scene-lexicon.json` (or embedded
   Swift) is the deliverable; tests assert per-scene minimum coverage.
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

---

### G. Pangram Hunt boss capstones

The **last level of every pack (level 10)** — the level that reveals the pack's
**signature creature** (workstream C) — swaps the crossword for a harder
**Pangram Hunt** format. This makes the capstone feel like a boss and rewards
the pack's difficulty ramp.

**Format:** no interlocking grid. The player is given the shuffled wheel and must
**find the pangram** (the word using *all* N wheel letters — the "key" that
unlocks the creature) **and** reach a **word-count target** `T` (so it is not a
single lucky guess). `T` scales with the band (e.g. 4 easy → 8 master).

- The **key word is scene-related** where possible (reuses workstream F: the
  capstone's wheel is derived from a scene-related word of exactly N letters,
  which is guaranteed to have at least one pangram — itself).
- **Progress/reveal:** `stir` is driven by words found toward `T` and spikes on
  the pangram; the signature-creature reveal (workstream A) plays on win.
- **UI:** the play screen hides the grid and shows a **Pangram Hunt panel** —
  the found-words tray (workstream C), an "N-letter word: ▢▢▢▢▢▢" prompt, and
  progress toward `T`. Wheel, ribbon, input, hints, and audio are unchanged.
- **Hints on a boss:** `revealHintCell` is grid-specific and does not apply; the
  boss offers a **"reveal a letter of the key word"** hint instead (same
  serenity cost), so hints stay meaningful without trivializing the pangram.

**Engine change:** introduce `LevelFormat { case crossword; case pangramHunt(target: Int) }`
on `Level`. `GameEngine.isComplete` and scoring branch on it:
- `crossword` — unchanged (all slots filled).
- `pangramHunt` — complete when `pangramCount >= 1 && foundWords.count >= target`.
The crossword path (`level.slots`) is empty for a boss; `submit` treats every
valid word as a bonus/collected word and tracks the pangram via the existing
`isPangram`. Doom capstones still catalog the signature creature to the
bestiary; Zen capstones reveal a calm guardian (unchanged rule).

**Generation:** `ProceduralGenerator` checks whether the seed's order is a pack
capstone (via `PackCatalog`/`packSize`) and, if so, emits a `.pangramHunt`
level: pick the scene-related N-letter key word, wheel = its multiset, no grid,
`target` from the band. Non-capstone levels are unchanged.

**Testing:** capstone detection (order % packSize == packSize-1) selects
`pangramHunt`; a boss level's wheel admits at least one pangram; `isComplete`
requires both the pangram and `target` words; scoring credits the pangram
bonus; determinism preserved.

## 5. Data model changes (summary)

- `SaveState`: `premiumUnlocked: Bool`, `ownedCosmetics: Set<String>`,
  `lastPlayedDate` + `streak`, (serenity already present).
- `Level`: `format: LevelFormat` (`.crossword` default / `.pangramHunt(target:)`).
- New pure types: `SceneLexicon`, `PackCatalog`, `LevelFormat`, `MusicalPalette`,
  `SoundCue`, protocols `SoundEngine` / `StoreService`.
- `WheelView`: `displayOrder: [Int]`; `GameViewModel`: owns display order +
  shuffle, emits `setMood`/`SoundCue`.

## 6. Sequencing

1. **F** (scene-coupled words) + **A-wheel-shuffle** — pure generator + small UI;
   fully unit-testable, no new deps.
2. **A-reveal** — swap the play-screen background to real art.
3. **G** (Pangram Hunt boss capstones) — `LevelFormat` engine branch + generator
   + boss UI; pure engine work is unit-testable. Depends on C's `PackCatalog`
   for capstone detection, so land `PackCatalog` (from C) first or alongside.
4. **B** (audio) — new dep + module; `NullSoundEngine` keeps CI green.
5. **C** (packs, celebration, tray, stats, first-letter hints).
6. **D** (StoreKit unlock + serenity packs + cosmetics + AdMob ads + privacy).

## 7. Resolved decisions

1. **SceneLexicon authoring** — generated **once, offline, per bundle** into a
   checked-in resource (with a generation script + hand review), not at runtime.
2. **Monetization model (revised 2026-07-02)** — free-to-play with **no content
   paywall**; ad-supported after pack 1 (cut-scene ads only); **premium $4.99 =
   remove ads** (non-consumable, **no Family Sharing**).
3. **Serenity packs** — three consumables: `$0.99 → 10`, `$1.99 → 25`,
   `$3.99 → 50`; cosmetics priced ~25–75 serenity. Serenity counters (menu/HUD)
   and the "Not enough serenity" hint message are **tappable**, opening the
   top-up sheet — the only in-play path; no popups.
4. **Cosmetic scope** — **both** scene palettes **and** cut-scene poem sets.
5. **Ad provider** — **AdMob, single network**, personalized by default with a
   Settings opt-out; ATT prompt required, non-personalized fallback on denial.

### Remaining to finalize during implementation

- Exact per-band Pangram Hunt `target` values (workstream G) — tune from
  playtests; the spec's 4→8 is a starting point.
- Exact cosmetic catalog (how many palettes / poem sets ship in v0.2).

## 8. Testing philosophy (unchanged)

Pure cores (`GameCore`, `LevelGen`, new `SceneLexicon`/`PackCatalog`/
`LevelFormat` completion/`MusicalPalette`/store gating) stay UI-free and fully
unit-tested. Hardware/
service paths (AudioKit, StoreKit, AdMob) sit behind protocols with null/mock
implementations so CI needs no entitlements or devices.
