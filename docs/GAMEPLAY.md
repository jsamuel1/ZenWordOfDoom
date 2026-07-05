# Gameplay — as shipped

The player-facing rules as they actually work today. `SPEC.md` holds the
original vision (with `Shipped:` deltas); `ARCHITECTURE.md` holds the
implementation detail; this file is the rules reference. Update it in the
same change as any rules change — see `CLAUDE.md` "Documentation upkeep".

## Core loop

Build words from a wheel of 5–9 letter tiles to fill an interlocking
crossword. Finding words raises the level's **stir** meter, gradually
surfacing a hidden creature in the scene; completing the level snaps the
reveal, celebrates, and breathes out through a haiku cut-scene showing the
level's art.

- **Input:** tap tiles, swipe-to-connect, or speak the word (voice input,
  Settings toggle, on-device recognition). All three feed the same
  submission pipeline.
- **Words:** minimum 3 letters, maximum the wheel size. A word matching an
  unsolved grid slot fills it without a dictionary check (the generator
  guaranteed it's real). Anything else is checked against the iOS system
  dictionary (`UITextChecker`) — valid non-grid words land as **bonus
  words** (smaller score, small serenity, no cell).

## Level formats

- **Crossword** (default): fill every grid slot to clear.
- **Pangram Hunt** (bosses + the daily): no grid — find the pangram (a
  word using every wheel letter; the wheel is always a real word, so one
  exists) plus a word-count target (4–8 by wheel size, +1/+2 at
  medium/hard difficulty tiers).

## Difficulty: a 2-D ladder

Two independent axes, both derived from the play order:

- **Wheel size (band):** each pack of 10 walks one size; sizes cycle
  5→6→7→8→9 across packs.
- **Richness tier:** every full size cycle (5 packs) escalates the anchor
  pool tier — **easy** (rich pools, lots of findable words) → **medium**
  → **hard** (barely more findable words than the grid demands). The
  infinite tail keeps cycling sizes at hard tier.

So packs 1–5 are the gentle ramp, 6–10 re-walk the sizes with leaner
pools, 11–15 at hard, then forever-hard with rotating sizes (~150-level
ramp). Wheels come only from pre-validated anchor pools (common words,
sanity-gated, quality floors — `docs/ARCHITECTURE.md` §4), the scene's
slug steers which anchor via affinity, and consecutive levels never deal
the same letters.

## Doom mode (Settings toggle; applies to any level)

A countdown (240s; 360s with Reduced Doom) that is a **bonus window, not
a fail state**: words score **4x** with more than 2/3 of the clock left,
**3x** above 1/3, **2x** with any time left, and **1x** after expiry —
points never stop, only the multiplier. Expiry also forfeits the level's
serenity payouts. No retry; the level continues to the clear either way.
The multiplier applies to score only, never to serenity.

## Hints

- **Paid hint:** 10 serenity reveals one unfilled cell of an unsolved slot
  (deterministic order per level). Refunded if nothing is left to reveal.
  Every hint costs the same; a clear that used any hint pays the reduced
  clear reward (see `docs/ECONOMY.md`).
- **First-Letter Hints** (Settings, free): casual-assist mode that
  pre-reveals each slot's first letter at level start.

## Progression, daily, and collection

- **Linear unlock:** levels play in order; clearing one unlocks the next.
  Packs of 10, each ending in a boss whose first clear pays the big
  serenity bonus and reveals a signature creature.
- **Daily (Word of the Day):** one global puzzle per calendar day — a
  Pangram Hunt on a curated word's letters with matching illustration.
  The streak advances on any clear (campaign or daily), never on merely
  opening the app.
- **Bestiary:** Doom-themed levels catalogue their revealed creature; Zen
  levels reveal a calm guardian that is deliberately not collected.
- **Scoring:** per-word points grow with length (10/letter + length²),
  pangrams +50, bonus words 5/letter; doom multiplier applies on top.
  Best score per level is kept.
