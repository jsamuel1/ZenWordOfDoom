# Zen Word of Doom — Deep Review

*Snapshot: 2026-07-05, reviewed at v0.4.14. Covers gameplay, aesthetics, code
structure, desirability, and potential value. Companion docs:
[`SPEC.md`](SPEC.md) (design intent), [`ARCHITECTURE.md`](ARCHITECTURE.md)
(system as shipped), [`ROADMAP.md`](ROADMAP.md) (milestones).*

**TL;DR:** A rare inversion of the usual indie profile: the engineering is
production-grade (honest A−) while the *content* is still a v0.3 seed. The
"zen meets doom" premise is genuinely distinctive in a saturated genre, the
monetization is unusually ethical, and the architecture would let content
scale fast — but late-game generation repeats badly, one class of boss level
may be literally unwinnable, and the meta-game (5 cosmetics, shallow
bestiary) can't yet hold a retained player. The bones are excellent; the
flesh is thin.

| Dimension | Grade | One-liner |
| --- | --- | --- |
| Gameplay | B | Solid loop, smart doom-multiplier tension; thin mid-puzzle juice, punitive hints |
| Aesthetics | B+ | Real identity (parchment, blackletter, generative audio); uneven in the meta screens |
| Code structure | A− | Pure cores, protocol seams, doc discipline; a few real gaps |
| Desirability | B− | Strong hook, positioning tension, retention content not there yet |
| Potential value | B | Modest as-is revenue; high value as a platform and portfolio piece |

## 1. Gameplay

The core loop is sound and complete: build words from a 5–9 letter wheel
(tap, swipe, *or voice* — a genuinely rare tri-input), fill an interlocking
crossword, watch the "stir" meter surface a hidden creature, exhale through
a haiku cut-scene. Difficulty escalates cleanly by pack (wheel size 5→9),
capstone "pangram hunt" bosses change the rhythm every tenth level, and the
daily puzzle is deterministic-per-date with streaks. The doom timer is a
bonus window (4x/3x/2x by time remaining, base points after expiry) rather
than a punishment — the right incentive shape.

Three serious content-pipeline problems:

1. **Master-band repetition (the biggest risk).** Wheels are derived from a
   scene's curated lexicon, and several scenes have exactly *one* 9-letter
   word (`scene-lexicon.json`: bamboo-grove GREENWOOD, misty-peak MOUNTAINS,
   sand-ripples SANDSTORM, willow-bank RIVERSIDE, thorn-hollow THORNIEST,
   drowned-temple SUBMERGED). The infinite campaign converges to roughly
   7–14 distinct wheels per theme at master band, forever. Long-tail
   retention dies here. Expert (8-letter) is only slightly better.
2. **Possibly unwinnable bosses.** Capstone/daily pangram hunts require
   spelling the anchor word itself, but nothing verifies the anchor is in
   the runtime dictionary — `VERDANCY` (moss-garden's 8-letter anchor) is
   already absent from the bundled ENABLE `words.txt`. If `UITextChecker`
   also rejects it, that boss cannot be cleared. `SolvabilitySweepTests`
   only checks `multiset.canBuild` (letters present), not word validity,
   and sweeps fake pools rather than the real content — so this class of
   bug ships undetected.
3. **Spec violations and spikes.** `daily-zen.txt`/`daily-doom.txt` contain
   ten 10-letter words each (APOCALYPSE, MEDITATION, NECROMANCY, …) which
   produce 10-tile wheels, violating SPEC §3's 5–9 range. And the "fewer
   than 3 interesting words" fallback injects obscure ENABLE words (the
   code's own example: LEPTA) as *required* grid answers — a
   recognizability spike that contradicts the readable-puzzles pillar.

Smaller frictions:

- **Hint economics are punitive:** a hint costs 10 serenity; a clean clear
  pays 8 (5 if a hint was used). One hint costs more than the level it's
  spent on, and the $0.99 pack buys exactly one hint — reads as an IAP
  funnel and may frustrate.
- **Two hint systems, unexplained:** the free First-Letter Hints toggle
  (Settings, default off) coexists with paid serenity reveals with no
  in-context explanation; players can easily miss the free one.
- **Pack/theme incoherence:** theme flips on prime-numbered levels, so a
  zen-named pack ("Still Waters") can contain doom scenes and vice-versa —
  pack names/flavors don't match their contents.
- **Emergent grid density:** the greedy layout guarantees connectivity but
  silently drops unplaceable words and doesn't enforce SPEC §4.1's "≥1
  pangram answer at bands 7+" for normal levels, so same-band levels vary a
  lot in density.

## 2. Aesthetics

The game has an actual identity, which most word games don't:

- Buda serif against Grenze Gotisch blackletter for the zen/doom split.
- The zen-rock/basalt parchment chrome (picture-frame ring + mat) across
  buttons, panels, and readouts.
- Hero illustrations, scene/creature art, twisted haiku cut-scenes.
- A sleeper standout: a fully **asset-free generative audio engine**
  (`AVAudioSoundEngine`) — a real-time synth whose drone, arpeggio, and cue
  voices react to the doom "stir." No audio files at all.
- The level-clear celebration (score count-up, serenity, NEW CREATURE
  fanfare) is a properly juicy beat with a full reduced-motion path.

The emotional arc from SPEC §2 ("calm → curiosity → mild dread → release")
is legible in the actual product, not just the spec.

Where it's uneven:

- Mid-puzzle the grid barely celebrates (a tint on solve); most juice is
  deferred to the clear beat.
- Level select is a plain text list despite the app sitting on a large
  scene/creature art library.
- The Shrine sells palettes/poem sets blind — name + flavor text, no
  preview of what a palette does.
- A few surfaces still use stock chrome amid the parchment language (the
  cut-scene's `borderedProminent` Continue, the doom-expiry overlay card).
- Accessibility, by contrast, is best-in-class throughout: WCAG-pinned
  palettes, reduce-motion/reduced-doom paths, audited screens, 44pt floors.

## 3. Code structure — A−

Scope: ~7k lines production Swift (GameCore 994, LevelGen 1080, App 5993),
~2.7k lines of tests (238 test functions across 49 files).

Strongest aspects:

1. **Module boundaries & dependency inversion.** `GameCore` and `LevelGen`
   are provably UI-free (zero SwiftUI/UIKit/AVFoundation/Combine imports);
   every platform integration is a protocol (`WordValidating`,
   `SoundEngine`, `StoreService`, `AdService`, `SceneVisualProvider`) with
   Null/Mock doubles behind lightweight environment "Box" holders.
2. **Documentation & cleanliness.** ~1 doc line per 7 code lines, and the
   comments explain *why* (layout math, audio-session ordering, audit
   rationale). Zero TODO/FIXME, zero force-unwraps/`try!`/`print` in
   production.
3. **Concurrency & memory discipline.** `@MainActor` on all stateful app
   objects; heap-allocated `os_unfair_lock` correctly shared with the
   audio render thread; `[weak self]` and task cancellation everywhere it
   matters; AdMob delegate hops via `Task` rather than `assumeIsolated`.

Also good: forward/backward-tolerant save decoding (`decodeIfPresent ??
default` per field), bounded `processedTransactionIDs` for StoreKit dedup,
graceful degradation on every failure path, deterministic test seams
(`debugSetDeadline`, `SeededRandom`, injectable stores/defaults), and the
accessibility test suite (XCUI audits + WCAG contrast unit tests).

Weakest aspects / real gaps:

1. **The monetization delivery path is untested** — `StoreKitStoreService`
   purchase→entitlement and the real ad loader have no coverage (only the
   downstream `GameStore.creditPurchase` dedup is tested).
2. **No save-schema version field** — migration relies purely on
   additive-key tolerance; a breaking *type* change to an existing field
   would silently reset that value with no detection path.
3. **Silent resource loading** — every lexicon/corpus load is
   `try? … ?? []`; a missing bundle resource yields an empty corpus and a
   runtime generation failure instead of a build/test-time break (and
   `WordOfTheDay.word`'s `precondition` would crash the daily).
4. **One fragile seam** — the manual `AVAudioSession` hand-off between
   voice input (`.record`) and the sound engine in `GamePlayView` is
   exhaustively commented but inherently delicate.
5. **No SwiftLint/SwiftFormat** — nothing enforces the (currently
   excellent) style against future drift.

Infra is solid: XcodeGen-generated project (no `.pbxproj` conflicts), CI
runs pure `swift test` plus a full simulator build+test on every push, and
the `Release` workflow does bump+commit+tag atomically with double-run
guards.

## 4. Desirability

The word-puzzle genre is enormous but brutally saturated and dominated by
dark-pattern-heavy incumbents. The differentiators here are real:

- A tone no competitor has — horror-tinged zen is memorable and streamable.
- Explicit no-dark-patterns design (every level free, ads only between
  levels after level 10, native cards with an always-available skip path).
- On-device AI generation (Image Playground scenes, Foundation Models word
  enrichment) as both feature and marketing angle.
- Accessibility as a genuine selling point.

The tension: the horror flavor may narrow the casual-puzzle audience the
mechanics serve, while the mechanics are too gentle for players drawn by
the doom aesthetic. "Reduced Doom" hedges this well; positioning should
probably lean "the word game with a soul" rather than horror.

What desirability lacks today is *depth to stay for*: 5 cosmetics total
(three palettes, two poem sets, ~225 serenity to clear the catalog),
bestiary entries that are just a portrait + "first seen in," static stats,
zen guardians visible in-game but never collectible, and the master-band
wheel repetition ceiling.

## 5. Potential value

**As a revenue product today: modest.** A $4.99 remove-ads, gentle
consumables ($0.99/$1.99/$3.99 serenity), cut-scene-only ads, and thin
sinks put a low ceiling on ARPU. The realistic near-term outcome is a
small, well-reviewed indie whose ratings are driven by the ethics and
accessibility.

**As a platform: high.** The pure cores and protocol seams make content
packs, themed spin-offs, seasonal events, or a second reskinned game cheap
to build. The serenity economy, generation pipeline, and chrome system are
all reusable.

**As a portfolio/showcase piece: already A-tier** — on-device AI
integration, a dependency-free reactive synth, accessibility discipline,
and clean CI/release automation are each individually uncommon; together
they're a strong calling card.

## 6. Appendix: word-list / solvability deep dive (data-verified)

*Added 2026-07-05 after running the real corpus and a Python re-implementation
of the exact generation pipeline (legacy FNV-1a basis + SplitMix64 +
prime-count theme rule) over the first 2,000 campaign orders. Two claims in
§1 are corrected below.*

### Corrections to §1

- **The 10-letter dailies are winnable.** The bundled `words.txt` is
  length-capped to 3–9 letters, so 10-letter daily words are "missing" from
  it by construction — but runtime validation is `UITextChecker`, which
  accepts them, and `WordOfTheDaySolvabilityTests` already handles the >9
  case explicitly. Every daily word of length 8/9 IS in ENABLE, and every
  daily's buildable pool (65–582 words) clears its pangram target. The
  10-tile wheels remain a **spec violation** (SPEC §3 says 5–9) and a
  layout/UX question, not a solvability bug.
- **VERDANCY is a landmine, not a live bug.** It is genuinely absent from
  ENABLE with zero ENABLE anagrams — but simulating orders 0–1,999 shows it
  is *never selected*: the expert band exists only for orders 30–39 (ten
  levels, ever), and moss-garden is never the picked zen scene in that
  window. It is unreachable dead data today; any change to pools, seeds, or
  pack size could expose it.

### The difficulty curve is a 40-level ramp, then flat forever

Bands easy/medium/hard/expert each exist for exactly ten levels (orders
0–9/10–19/20–29/30–39). **Everything from order 40 on is master.** The
"progression" is really a fixed 40-level campaign plus an infinite master
tail.

### The master tail has 21 wheels, total

Distinct anchors reachable per theme/band (real `scene-lexicon.json` +
`seed-*.txt` fallback): zen 25/46/16/13/10 and doom 21/40/24/13/11 for
lengths 5/6/7/8/9. Simulating the 120 master levels at orders 40–159:

- **21 distinct wheels** (10 zen + 11 doom) cover all 120 levels.
- RIVERSIDE ×14 and SUBMERGED ×14 are the most repeated.
- **10 back-to-back identical wheels** (e.g. orders 42–43 both RIVERSIDE,
  50–51 both SUBMERGED) — the same letters two levels in a row.
- Bosses repeat normal levels' letters at close range (THORNIEST at 41 and
  46, then again as the order-49 boss; WATERWAY at 37 and as the order-39
  boss).

Master pools themselves are healthy (43–338 buildable words each, top-24
provider pool fully "interesting") — the tail problem is letter repetition,
not pool weakness.

### Four of the first 40 levels have weak pools (obscure required answers)

Reproducing the provider ranking (lexicon → common → longer → alpha, top
24) and the generator's interesting-word filter for the 36 non-boss levels
in the fixed campaign:

| Order | Wheel | Buildable | Interesting | Obscure filler that becomes required answers |
| --- | --- | --- | --- | --- |
| 2 | RIVER | 7 | 5 | RIVE, RIV |
| 6 | MISTY | 12 | 4 | MYST, STIM, ISM, MIT, MST, SIM, STY, TIM |
| 7 | QUIET | 8 | 4 | QUE, TUE, TUI, UTE |
| 16 | SKULLS | **5** | 4 | USS |

These are below the `minInterestingSlots = 3` fallback threshold's comfort
zone — the layout will draw from the full pool and require words like RIV
and MYST. Orders 2, 6, 7 are in a player's **first session**, where
recognizability matters most. SKULLS (order 16) is the worst wheel in the
game: five buildable words total on a 6-letter wheel.

### Test-coverage gap, precisely

- `SolvabilitySweepTests` sweeps orders 0–49 with **fake pools**
  (`scenes: ["garden","pond"]`), so none of the real-content findings above
  are in its net, and it checks `canBuild` only — never dictionary
  membership of anchors.
- `WordOfTheDaySolvabilityTests` is good (count target, >9 handled) but
  only covers dailies, not capstone anchors.

### Concrete fix list (supersedes recommendation 1's wording)

1. **Guard test — anchor validity:** every `scene-lexicon.json` +
   `seed-*.txt` word of length 5–9 must be present in `words.txt` (catches
   VERDANCY-class landmines at build time; ENABLE membership is the best
   CI-runnable proxy for `UITextChecker`).
2. **Guard test — real-content sweep:** run the solvability sweep over
   `ThemePools.zenDoom` + the real lexicons for orders 0–200, asserting
   pool health (e.g. ≥ 8 interesting words per grid level) and no
   back-to-back identical wheels.
3. **Fix the four weak early wheels:** replace RIVER/MISTY/QUIET (easy) and
   SKULLS (medium) in the scene lexicons with richer-pool alternatives, or
   have the generator reject wheels whose interesting pool < ~10 and re-pick.
4. **Break the master tail:** expand 9-letter scene lexicon entries (each
   scene has 1–2 today; ~6+ each would give the tail ~40–80 wheels), and/or
   add an anti-repeat rule (re-pick when the anchor equals either of the
   previous two levels' anchors).
5. **Decide the 10-letter dailies:** cap curation at 9 (matching SPEC §3
   and the corpus), or amend the spec and verify the wheel UI at 10 tiles.

## 7. Recommendations, in order

1. **Correctness first (ship-blockers in the long tail):** validate every
   capstone/daily anchor against the runtime dictionary; add a
   real-content solvability sweep (real `ThemePools`/`scene-lexicon.json`,
   word-validity not just buildability); decide the 10-letter daily
   question (cap at 9 or amend the spec).
2. **Break the repetition ceiling:** expand 8/9-letter scene lexicons
   substantially, or decouple high-band wheels from scenes.
3. **Rebalance hints** (first hint cheap, or raise clear rewards) and
   surface the free first-letter option in context.
4. **Deepen the sinks:** 15–20 cosmetics with live previews; bestiary lore
   per creature. This is where retention and serenity demand come from.
5. **Juice the mid-loop:** per-cell fill animation, grid celebrations,
   scene art in level select.
6. **Harden the base:** save-schema version field, StoreKit delivery
   tests, SwiftLint, and make resource loading fail loudly in tests.
