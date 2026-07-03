# Word of the Day

**Status:** Design approved (brainstorm), pending implementation plan.
**Date:** 2026-07-03

## 1. Summary

The existing Daily level slot (`daily-yyyy-MM-dd`, already has a menu card +
streak tracking) becomes a **bonus Pangram-Hunt puzzle** built from a single
hand-curated 8-10 letter Zen or Doom word — the "Word of the Day" — instead of
a corpus-ranked crossword. Every player sees the same word on the same
calendar day (deterministic, no server needed). It is purely a bonus: it does
not gate campaign progression and can be skipped at any time by choosing any
other level from level-select (unchanged existing behavior).

Each curated word is grouped into one of roughly 20-30 shared illustration
slugs (multiple words per image), whose art is generated once offline via the
**`agy`** (Google Antigravity) CLI and bundled into the asset catalog exactly
like the existing scene/creature `BundledVisuals` system. This image
**replaces** the puzzle's normal scene/creature reveal art for the daily slot.

## 2. Goals / non-goals

**Goals**
- Same curated word for every player, every day, deterministic by calendar
  date, no server round-trip.
- Reuse the existing Pangram-Hunt mechanic (wheel = the word's own letters,
  find sub-words + the pangram) rather than inventing new gameplay.
- Curated word list is hand-picked for tone (evocative Zen/Doom vocabulary),
  not algorithmically ranked from the general corpus.
- No repeats until a theme's full curated list has cycled once.
- Stays a bonus/optional slot — doesn't block level-select progression,
  skippable like today's daily card already is.
- Each word's reveal image comes from a small (~20-30), hand-curated,
  offline-generated set — not per-device runtime generation.

**Non-goals**
- Changing daily streak/save-state mechanics (`GameStats`, `SaveState`
  keying) — unchanged.
- Per-device/runtime image generation for word-of-the-day art (that remains
  `ImagePlaygroundVisualProvider`'s job for regular scenes; this is a
  separate, pre-baked set).
- Retiring or changing the *regular* (non-daily) crossword/scene/creature
  system.
- A full authoring UI for curating words/slugs — a flat resource file plus a
  mapping table is enough.

## 3. Key decisions (from brainstorm)

1. **Integration point:** the existing Daily slot, not a new mode.
2. **Theme (Zen/Doom):** continues to follow the existing hash-parity rule
   already used by `DailyPuzzle` — unchanged.
3. **Mechanic:** existing Pangram-Hunt format; the wheel is built directly
   from the curated word's own letters, guaranteeing it is always a
   completable pangram.
4. **Word list size/cadence:** ~50-100 words per theme, deterministically
   shuffled per full cycle (no repeat until the list is exhausted, then
   reshuffles differently).
5. **Word length:** 8-10 letters. The existing single-circle wheel layout is
   tuned for a 9-tile max, so it can't just be stretched to 10 — instead,
   wheels of 8+ tiles (Expert, Master, and the new 10-letter case) switch to
   a new **two-row stadium shape** (§4.3), not just the 10-letter case.
6. **Images:** ~20-30 bundled illustration slugs shared across words (many
   words per slug), generated offline via the `agy` CLI, replacing the
   puzzle's normal reveal art for the daily slot only.

## 4. Architecture

### 4.1 Word selection (pure, `LevelGen`)

```
Sources/LevelGen/Resources/daily-zen.txt   // curated 8-10 letter Zen words
Sources/LevelGen/Resources/daily-doom.txt  // curated 8-10 letter Doom words
Sources/LevelGen/WordOfTheDay.swift        // new
  - loads both lists (same pattern as ThemeLexicon/GeneralWordList)
  - word(forTheme:dayNumber:) -> String
      cycleLength = list.count
      cycleIndex  = dayNumber % cycleLength
      cycleNumber = dayNumber / cycleLength
      shuffled = list shuffled with seed FNV1a.hash("wotd-\(theme)-\(cycleNumber)")
                 (Fisher-Yates via the existing SeededRandom)
      return shuffled[cycleIndex]
```

`dayNumber` is the count of whole days since a fixed epoch (e.g.
2026-01-01), computed from the daily id's year/month/day — a pure,
Foundation-`Calendar`-based day difference, consistent with `DailyPuzzle`'s
existing style. Using a per-cycle shuffle (rather than a hash-modulo pick)
is what guarantees no repeat within a cycle — a plain hash-mod does not have
that property.

`DailyPuzzle.swift` gains one new entry point that combines its existing
theme/day parsing with the new word source:

```swift
public static func wordOfTheDay(forID id: String) -> (theme: Theme, word: String)?
```

### 4.2 Level generation

`ProceduralGenerator` gains a new, synchronous `dailyLevel(for:word:)`. No
`wordProvider` is needed — Pangram-Hunt levels never touch it today either
(true for existing pack-capstone bosses):

```swift
public func dailyLevel(for seed: LevelSeed, word: String) -> Level {
    let visual = SceneCreaturePicker(pools: pools).pick(theme: seed.theme, index: seed.index)
    return Level(id: seed.id, wheel: Wheel(letters: word), slots: [],
                 sceneID: visual.sceneID, creatureID: visual.creatureID,
                 format: .pangramHunt(target: PackCatalog.pangramTarget(for: seed.band)))
}
```

`LevelService.level(id:)`'s existing `DailyPuzzle.isDailyID(id)` branch
switches to this path instead of the generic `generator.level(for:)` call.
Caching/re-keying by date is unchanged.

### 4.3 Wheel UI (two-row stadium shape for 8+ tiles)

Wheels of 8 or more tiles (Expert=8, Master=9, and the new 10-letter
Word-of-the-Day case) drop the single-circle layout in favor of a **two-row
stadium shape**, confirmed via mockup review:

- **Row split:** even split, remainder on the bottom row — 8→4+4, 9→4+5,
  10→5+5.
- **Tile placement:** each row is itself a shallow arc rather than a flat
  line — the top row sags gently downward at its ends, the bottom row
  rises gently upward at its ends, so the two rows curve toward each other,
  giving the wheel a lens/stadium silhouette that echoes the original
  circle rather than reading as two flat bars.
- **Same-row drag trail:** when the player drags between two tiles in the
  *same* row, the connecting trail curves **inward** — toward the gap
  between the two rows — rather than following the row's own outward bow or
  bulging away from it.
- **Cross-row drag trail:** dragging between a top-row and bottom-row tile
  uses a straight line, as today (only same-row segments get the arc
  treatment). Flag this as an assumption to confirm during implementation if
  it feels wrong in practice.

Wheels under 8 tiles (Easy/Medium/Hard) keep today's single-circle layout
unchanged. This is new layout code in `WheelView` (or a sibling type), not a
tweak to the existing circular radius formula — needs both a geometry pass
(row curvature, tile spacing so nothing overlaps) and a simulator visual
check, since the curvature amount is an aesthetic judgment, not purely
numeric.

### 4.4 Word → image mapping & bundled art

```
App/ZenWordOfDoom/BundledVisuals.swift   // extend
  - new VisualKind case, e.g. .dailyWord
  - knownAssets gains "dailyword-<slug>" entries (~20-30 total)

Sources/LevelGen/VisualPrompts.swift     // extend
  - dailyWordPrompts: [String: String]   // slug -> illustration prompt

Sources/LevelGen/WordOfTheDayImages.swift (new)
  - word -> slug mapping (many words per slug; hand-curated by mood/imagery)
```

For the daily slot specifically, the reveal swaps its `VisualRequest` from
the level's `sceneID`/`creatureID` to `(.dailyWord, slugForWord)` — the
word's image **replaces** the normal scene/creature reveal art for that
puzzle. Everything downstream (caching, procedural fallback if a slug isn't
yet bundled) reuses the existing `SceneVisualProvider`/`VisualCache`/
`BundledVisuals` machinery unchanged.

### 4.5 Offline image authoring

A small script drives the **`agy`** CLI (Google Antigravity, local CLI,
confirmed capable of producing images from a prompt) once per slug,
submitting each slug's `VisualPrompts` entry and saving the result into
`Assets.xcassets` under the `dailyword-<slug>` naming convention — matching
how the existing scene/creature bundled art was produced.

`agy` has usage limits that can throttle a tight batch of 20-30 generations
in a row. The script paces requests (delay between calls, retry-with-backoff
on a throttle response) rather than firing all slugs back-to-back, and is
re-runnable/idempotent (skips slugs that already have a bundled asset) so a
throttled run can simply be resumed later.

## 5. Data flow (daily puzzle open → reveal)

1. Player opens the Daily card (unchanged; still shows streak).
2. `LevelService` resolves `daily-<date>` → `DailyPuzzle.seed(forID:)`
   (theme/band/index, unchanged) + `DailyPuzzle.wordOfTheDay(forID:)` (new:
   theme + curated word).
3. `ProceduralGenerator.dailyLevel(for:word:)` builds the Pangram-Hunt
   `Level` directly from the word's letters.
4. Gameplay is the existing Pangram-Hunt experience (drag-trail wheel,
   sub-word discovery, pangram + word-count target) — unchanged.
5. On completion, the reveal shows the word's bundled image (via its slug)
   instead of the usual scene/creature art.
6. `GameStore`/`GameStats` streak/progress recording is unchanged (still
   keyed by `daily-<date>`).
7. Skip: level-select's normal "next level" flow is completely unaffected —
   nothing about the daily slot gates or blocks it (already true today;
   explicitly preserved, not newly built).

## 6. Risks & open questions

- **Word→slug curation is manual** — grouping ~100-200 curated words into
  ~20-30 thematically coherent image buckets is a judgment call, done by
  hand during implementation.
- **Two-row stadium wheel layout** — new layout code for 8+ tile wheels
  (curved rows, inward-arcing same-row trail) touches shared rendering code
  (`WheelView`) used by Expert/Master levels too, not just the new daily
  case; needs a simulator visual check beyond the geometry, and the
  cross-row-drag-stays-straight assumption should be confirmed during
  implementation.
- **Curated word solvability** — every curated word must still yield a
  sensible Pangram-Hunt (enough valid sub-words buildable from its letters
  via the general corpus) — validated by a new test sweep akin to
  `SolvabilitySweepTests`.
- **`agy` throttling** — batch image generation must be paced/resumable (see
  §4.5); not a blocker, just an operational constraint on the authoring
  script.

## 7. Testing

- `WordOfTheDayTests` (new, `LevelGenTests`): deterministic per id,
  theme-parity matches `DailyPuzzle.seed`, no repeat within a cycle,
  reshuffle differs across cycles, list-loading correctness (all words 8-10
  letters, uppercase, present in the general corpus for dictionary
  validation).
- Solvability sweep: every curated word (both themes) produces a valid
  Pangram-Hunt level with the expected sub-word floor.
- `ProceduralGeneratorTests`: `dailyLevel(for:word:)` produces
  `.pangramHunt` format, wheel matches the word's letters exactly,
  scene/creature still assigned (used as fallback if a word's slug isn't
  bundled yet).
- `BundledVisualsTests`-style coverage extended for the new `dailyWord` kind
  and slug set.
- App-target: confirm the daily-slot reveal uses the word's bundled image,
  and that skipping to the next level from level-select is unaffected
  (regression guard for the "bonus, not gating" requirement).
