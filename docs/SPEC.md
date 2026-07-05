# Zen Word of Doom — Game Design & Functional Specification

- **Platform:** iPhone (iOS 26.5), Swift, portrait-first
- **Genre:** Word puzzle (anagram + crossword hybrid) with atmospheric reveal
- **Session length:** 2–10 minutes per level; designed for both short and long play
- **Status:** Living spec — implemented through v0.3 except where marked.

---

## 1. Concept

Zen Word of Doom looks like a calm, minimalist word game and plays like one —
but every level hides a Doom-like creature inside a serene Zen scene. The
player builds words from a wheel of letters to fill a crossword grid. Progress
gradually transforms the peaceful background, surfacing the lurking creature
before it settles back into stillness when the level is cleared.

The emotional arc of a single level: **calm → curiosity → mild dread →
release.**

### 1.1 Design pillars

1. **Tactile word-building.** Three input methods (swipe, tap, voice) that all
   feel good and are fully interchangeable mid-word.
2. **Readable puzzles.** The grid and wheel are always legible; difficulty
   comes from vocabulary and letter count, never from cluttered UI.
3. **The slow reveal.** The horror is ambient and never jump-scare cheap. It
   rewards attention, not punishes the player.
4. **Respectful calm.** No timers by default, no punishing fail states, no
   dark-pattern monetization. Doom is a *flavor*, not a difficulty stick.

---

## 2. Core gameplay loop

```
Enter level
  → See Zen scene + crossword grid (empty slots) + letter wheel
  → Build a word (swipe / tap / voice)
      → Valid + in grid  → letters animate into grid slot(s), scene shifts
      → Valid bonus word  → reward (coins / serenity), no grid slot
      → Invalid           → gentle shake, no penalty
  → Repeat until all grid slots filled
  → Level complete: creature fully revealed for a beat, then scene calms
  → Score / serenity tally
  → Inter-level cut scene ("breath"): moving Zen scene + twisted poem,
    a Doom monster/item pops out after a few seconds, then calm → next level
```

A level is **won** when every slot in the crossword grid is filled. There is no
lose condition in the default (Zen) mode.

---

## 3. The letter wheel

- A circular arrangement of **5 to 9 letter tiles**.
- Letters are the **shuffled multiset** of the longest target word(s) for the
  level. Duplicate letters are allowed (e.g. two `E` tiles) and appear as
  distinct tiles.
- **Each tile may be used at most once per word.** Re-using the same physical
  tile within one word is not allowed; a duplicated letter requires two tiles.
- Controls:
  - **Shuffle** button — re-randomizes tile positions (cosmetic; never changes
    the letter set).
  - **Clear / backspace** — cancels the current in-progress word.
- The wheel sits in the lower third of the screen, comfortably within thumb
  reach. The forming word renders as a "ribbon" above the wheel.

### 3.1 Letter count → difficulty

| Wheel size | Difficulty band | Notes |
| --- | --- | --- |
| 5 | Easy | Short grids, common words |
| 6 | Medium | Introduces 5–6 letter targets |
| 7 | Hard | Larger grids, less common words |
| 8 | Expert | Multiple long words |
| 9 | Master (max) | Dense interlocking grid |

Word length range per level is **3 … N**, where **N = wheel size**. Words
shorter than 3 letters are never accepted.

---

## 4. The crossword grid

- A set of **interlocking slots** (across/down) laid out like a small
  crossword, where every answer is an anagram subset of the wheel letters.
- Slots are **blank cells**; the player does not see the answer letters until a
  word is found. (Optionally, the first letter of each slot can be revealed as
  a hint — see §7.)
- When a valid word matches a grid answer, its tiles animate from the wheel
  into the corresponding cells.
- Shared/intersecting cells fill once and stay filled, helping subsequent
  words.
- **Bonus words:** valid dictionary words that use wheel letters but are *not*
  in the grid still count — they award currency/serenity and are collected in a
  "found words" tray, but do not fill grid cells. This rewards exploration
  without bloating the grid.

### 4.1 Grid generation rules

- Every grid answer must be constructable from the wheel's letter multiset.
- The wheel's letter set is the union (max multiplicity) of all grid answers,
  guaranteeing every answer is reachable.
- At least one answer must use **all N** letters (a "pangram-style" key word) at
  the harder bands (7+), to justify the full wheel.
- Grids are validated to be fully connected (standard crossword connectivity).

---

## 5. Input methods

All three methods produce the same internal event: an **ordered sequence of
tile IDs** → resolved to a word string → validated.

### 5.1 Swipe (drag-to-connect)
- Touch down on a tile begins a chain; dragging over adjacent or non-adjacent
  tiles appends them.
- A visible line/ribbon connects selected tiles.
- Back-tracking over the previous tile removes the last selection (common
  word-game convention).
- Lifting the finger submits the word.

### 5.2 Tap
- Tapping a tile appends it to the current word.
- Tapping a selected tile again (the most recent one) deselects it.
- A **submit** affordance (or tapping the formed word ribbon) submits.

### 5.3 Voice
- A mic button activates **on-device speech recognition** (`SFSpeechRecognizer`
  with `requiresOnDeviceRecognition = true` where supported).
- Recognized text is normalized (lowercased, stripped of non-letters) and
  matched against the wheel letter multiset.
- If the spoken word is buildable from the wheel and valid, it submits exactly
  as a swipe/tap would; the matching tiles light up to confirm.
- If recognition is ambiguous, the top candidate that is buildable + valid is
  chosen; otherwise a gentle "didn't catch that" cue.
- **Privacy:** voice is opt-in, on-device only by default, with a clear
  permission prompt. See §10.

### 5.4 Accessibility
- VoiceOver labels for each tile, the wheel, and grid slots.
- Voice input doubles as an accessibility input.
- Dynamic Type for all text; color-blind-safe palette; reduced-motion option
  that tones down the creature reveal animation.

---

## 6. The Zen / Doom aesthetic

### 6.1 Zen layer (default state)
Minimalist, painterly scenes: raked sand gardens, koi ponds, bamboo groves,
paper lanterns, misty mountains. Soft palettes, gentle parallax, ambient
particles (drifting petals, embers, mist). Calming soundscape: singing bowls,
water, wind chimes, low drone.

### 6.2 Doom layer (hidden creatures)
Each scene conceals a creature in its negative space, shadows, or texture
(e.g. a demon silhouette in the rocks, eyes in the pond reflection, a maw in
the bamboo shadows). The creature is part of the art, not an overlay.

### 6.3 The reveal mechanic
A per-level **"stir" meter (0–1)** drives how much the Doom layer surfaces:

- Each found word increases *stir* by a small amount.
- As *stir* rises: palette desaturates/reddens slightly, shadows deepen, the
  hidden creature's outline becomes more visible, ambient audio adds a low
  growl/heartbeat, subtle screen warp near the creature.
- At grid completion the creature **fully reveals for ~1.5s** (a held beat,
  not a jump scare), then the scene exhales back to full calm as the level
  resolves.
- **Reduced Doom** accessibility/setting: caps the reveal intensity and removes
  startling audio while preserving the art.

### 6.4 Tone guardrails
- No gore, no jump scares with loud stingers by default.
- The horror is *atmospheric and discoverable*. A first-time player can enjoy a
  pure word game and only gradually notice the watchers.
- Age rating target: **12+** (mild horror themes).

### 6.5 Icon & title art direction
The app icon and title/menu backdrop are a separate visual register from the
in-game procedural scenes (§6.1): bold, painterly-photoreal **"Zen with Doom"
/ "Doom with Zen"** hero illustrations — a serene figure or motif set directly
against overt Doom-style imagery (ruins, fire, armored figures, the void),
rather than a creature hidden in negative space. This is the first-impression
surface (App Store icon, title screen, marketing) and is allowed to be more
literal and striking than the discoverable, atmospheric in-game reveal.

- Bundled as static illustrations (`Assets.xcassets/TitleArt`, `AppIcon`),
  distinct from the on-device generated/procedural scene and creature art
  (§6.2, `VisualPrompts`), which keeps its IP-safe, non-figurative guardrails.
- Curated hero art may allude more strongly to the "Doom" half of the theme
  than the generated in-game content does; this is an accepted, deliberate
  trade-off for the icon/title surfaces specifically, not a relaxation of the
  IP guardrails elsewhere (§6.2's generated creatures/scenes stay abstract and
  avoid named IP).
- App icon: single 1024×1024 illustration, no text, readable at small sizes
  (home screen, Settings, notifications) — favor a strong central silhouette
  over fine detail that disappears when scaled down.

### 6.6 Inter-level cut scenes ("breaths")
Between levels the game plays a short, **skippable** cut scene — a moment to
relax and reset before the next puzzle. Each "breath" is a self-contained beat,
not a loading screen.

- **Moving Zen scene.** A gently animated vignette (drifting mist, rippling
  water, swaying bamboo, falling petals, slow parallax). Calm by design and
  visually distinct from the level it bridges.
- **The pop-out.** After a few seconds of calm (**~3–5s**, tunable), a **Doom
  monster or cursed item** emerges from the scene — peeking from the reeds,
  surfacing in the pond, unfurling from a shadow — holds for a beat, then
  recedes and the scene returns to calm. It is a *wink*, not a scare: timed and
  telegraphed, never a loud sting. Honors the **Reduced Doom** setting (softer,
  slower, or omitted pop-out) and **reduced-motion** (no lunge; a still reveal).
- **Twisted Zen poetry.** Each cut scene shows a short poem — haiku-like in form
  and serene in cadence, but quietly *wrong* underneath (calm surface, ominous
  undertow). It is there to read and relax by while the scene breathes. Example
  register (final lines authored in content, not hardcoded):

  > *Still pond at dawn —*
  > *the koi count the swimmers*
  > *who did not surface.*

- **Pacing & control.** Auto-advances after the poem has had time to land
  (readable at a calm pace), or on tap. Always skippable; a setting can disable
  cut scenes entirely. Respects Dynamic Type and VoiceOver (the poem is read
  aloud when VoiceOver is on).
- **Content.** Poems and pop-out creature/item are **data** (per [`GameCore`](ARCHITECTURE.md)),
  themed to the pack and ideally foreshadowing the next level's hidden creature,
  so the breaths form a loose through-line rather than random interludes.

---

## 7. Hints & assists

- **Reveal a letter** — fills one random correct cell. Costs currency.
- **Reveal a slot's first letter** — cheaper, scoped hint.
- **Highlight a startable slot** — points to where a word can begin.
- Optional **first-letter-shown** mode for casual players (toggle).
- Hints are optional and never required to progress.

**Shipped: single reveal-a-cell tier.** Only "reveal a letter" (a random
unfilled cell in an unsolved slot, deterministically seeded per level so a
given level reveals in a reproducible order) is implemented, at a flat cost
in serenity. The scoped "reveal a slot's first letter" and "highlight a
startable slot" hint tiers above are not built; the casual
**first-letter-shown** toggle is shipped separately as a settings-driven
assist (pre-reveals every slot's first cell for the whole level, at no
per-hint cost) rather than a purchasable hint tier.

---

## 8. Progression & meta

- **Level packs** themed by Zen scene (Garden, Pond, Grove, Peak…), each with a
  signature creature.
- Difficulty ramps wheel size within and across packs (5 → 9).

  > **Shipped (2-D ladder):** each pack walks one wheel size, sizes cycle
  > 5→9 across packs, and every full size cycle escalates the anchor-pool
  > richness tier (easy → medium → hard: fewer findable words on the same
  > wheel size) — a ~150-level ramp, with the infinite tail cycling sizes
  > at hard tier. See `ARCHITECTURE.md` §4/§4.1.
- **Linear unlock** — levels play in pack order; a level unlocks only once the
  preceding level is cleared. The home screen's **Play** drops the player
  straight into their next uncleared level, while **Select Level** opens the
  full list where cleared and unlocked levels are selectable and locked levels
  are shown but disabled.
- **Serenity** (soft currency) earned from words, bonus words, and clears;
  spent on hints and cosmetic scene unlocks.

  > **Shipped (Economy v2, ~0.8 hints earned per level):** new profiles
  > start with 50; a first-time, non-voided clear pays +1 (or +2 with the
  > no-hint bonus); +1 per bonus word, capped at 2 paid per level and only
  > before that level's first clear (no replay farming); a pack-capstone
  > boss's first clear pays a flat +50 (never score/timer-multiplied;
  > dailies don't qualify); repeat and doom-expired clears pay nothing;
  > hints cost a flat 10 — every hint, same price. Serenity IAPs are
  > 45/100/220. One price list (`GameCore.Economy`) is the single source —
  > see `ARCHITECTURE.md` §5.2 for the authoritative numbers and the
  > pack-yield test that pins the target.
- **Daily puzzle** — one fixed-seed level per day. **Implemented:** the same
  puzzle globally, for every player, on a given calendar day (seed derived
  from the date-keyed id); the streak advances on any clear, campaign or
  daily.
- **Streaks & stats** — words found, longest word, pangrams, creatures
  revealed ("bestiary" collection).
- **Bestiary** — a gallery of every creature the player has surfaced.

### 8.1 Game modes
1. **Zen mode (default):** no timer, no fail state, full assists allowed.
2. **Doom mode (optional):** a timer; the creature reveals faster. **As
   implemented,** the clock is a bonus window, not a forfeit: words score
   4x with more than 2/3 of the limit remaining, 3x above 1/3, 2x with any
   time left, and plain 1x after expiry — points never stop, only the
   multiplier does. Expiry does not fail or restart the level: the player
   continues the same level toward the clear (no retry), and an expired
   clear earns no serenity (see §8's economy note) though it still records
   progress, the streak, and the bestiary. This supersedes both the
   originally specified "soft fail / retry" and the interim "points
   voided" behavior.

---

## 9. Scoring

- Base points per word scale with length (longer = more).
- **Pangram bonus** for words using all N wheel letters.
- **Bonus-word** points for valid non-grid words (smaller).
- **No-hint clear** and **speed** bonuses (Doom mode).
- Per-level: words found / total grid words, bonus words found, stir peak,
  creature revealed (y/n).

---

## 10. Privacy & permissions

- **Microphone + Speech recognition:** requested only when the player first
  taps voice input, with an in-context explainer. On-device recognition
  preferred; nothing recorded or uploaded. Provide a clear
  `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`.
- No accounts required to play. iCloud/Game Center optional for sync &
  leaderboards.
- No third-party tracking SDKs in v1.

---

## 11. Content & data

- **Dictionary:** runtime word validation uses **iOS's built-in dictionary**
  (`UITextChecker`), so no word list needs to be bundled or licensed for
  validation. A small curated list is kept only for authoring/validating level
  content and tests.
- **Profanity / safe-word filtering:** offensive words are accepted for
  validation if real, but never required as grid answers; a configurable
  filter can hide them from bonus tallies.
- **Level data:** levels are authored/generated as data files (JSON), not
  hardcoded — see ARCHITECTURE §Level format. Each level specifies wheel
  letters, grid layout + answers, scene id, and creature id.

---

## 12. Out of scope for v1

- iPad / Mac Catalyst layouts (design portrait-iPhone first).
- Online multiplayer / head-to-head.
- User-generated levels.
- Localization beyond English (architecture should not preclude it).

---

## 13. Open questions

1. ~~Word list license — confirm a permissively licensed dictionary.~~
   Resolved: runtime validation uses the iOS built-in dictionary
   (`UITextChecker`); a bundled list is only needed for authored content.
2. Art pipeline — are creatures hand-painted per scene or composited from a
   shared shader/mask system? (Affects how the reveal is implemented.)
3. Voice matching strictness — accept homophones? Best-candidate vs. exact?
4. Monetization — premium one-time purchase, or free with cosmetic IAP? (Spec
   assumes no ads, no pay-to-win.)
5. Minimum iOS version vs. on-device speech availability per device.

See [`ROADMAP.md`](ROADMAP.md) for sequencing and [`ARCHITECTURE.md`](ARCHITECTURE.md)
for the technical plan.
