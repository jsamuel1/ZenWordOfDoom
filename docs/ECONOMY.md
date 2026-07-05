# Serenity Economy — as shipped

The authoritative description of every serenity faucet, sink, and price.
The single source of truth in code is `Sources/GameCore/Economy.swift`
(plus `StoreItem.serenityAmount` in `Store.swift` for IAP contents); this
document is its narrative twin. Change the code and this file together —
see `CLAUDE.md` "Documentation upkeep".

## Design target

Earned income of roughly **0.8 hints per level** (~8 serenity against the
10-serenity hint), averaged over a pack of 10 including its boss payday.
Pinned by `EconomyTests.testPackYieldIsNearDesignTarget` (fails CI outside
0.75–0.9). A clean pack yields ≈ 9 × (2 + up to 2 bonus) + (2 + 50 + up to
2) ≈ 80–90 serenity.

## Faucets (earning)

| Event | Serenity | Notes |
| --- | --- | --- |
| New profile | **50** | `Economy.startingSerenity`; a few hints of runway to learn the mechanic |
| First clear, no hint | **+2** | `Economy.clearReward` — 1 base + 1 no-hint bonus |
| First clear, hint used | **+1** | |
| Repeat clear | 0 | |
| Doom-expired clear | 0 | words still score points; serenity is forfeit |
| Bonus word | **+1**, max **2 per level** | `Economy.bonusWordReward` / `maxBonusRewardsPerLevel`; only while the level is uncleared; meter persisted in `LevelProgress.serenityBonusPaid` |
| Boss (pack capstone) first clear | **+50** | `Economy.bossClearReward`; flat — never score- or doom-timer-multiplied; dailies do NOT qualify (they'd pay daily) |
| IAP: small / medium / large | **45 / 100 / 220** | $0.99 / $1.99 / $3.99; value per dollar improves with size so no pack is dominated (`StoreTests.testNoPackIsDominated`) |

There are no other faucets: no rewarded ads, no daily-login or streak
serenity.

## Sinks (spending)

| Sink | Cost | Notes |
| --- | --- | --- |
| Hint (reveal one cell) | **10** | flat, every hint — no free or discounted first hint; refunded if nothing was left to reveal |
| Cosmetics (Shrine) | 25 / 40 / 40 / 60 / 60 | scene palettes + poem sets, **225** to clear the catalog (~1.5 clean packs of play) |

The free **First-Letter Hints** toggle in Settings is a casual-assist
*mode* (pre-reveals each slot's first letter), not a consumable — it costs
nothing and is unrelated to the paid hint.

## Anti-farming protections

- Bonus words pay only while their level is **uncleared**, and only up to
  the per-level cap — the meter is persisted, so relaunching or replaying
  cannot mint serenity.
- Repeat clears (including bosses) pay nothing.
- StoreKit consumables are deduplicated by transaction id
  (`SaveState.markTransactionProcessed`, bounded history), so replayed
  unfinished transactions credit exactly once.

## Changing the economy

1. Change numbers in `Economy.swift` / `Store.swift` only.
2. Update the pins in `Tests/GameCoreTests/EconomyTests.swift` (including
   the pack-yield range test) and `StoreTests`.
3. Update this file, `ARCHITECTURE.md` §5.2's pointer notes, and the
   SPEC §8 `Shipped:` amendment.
4. If IAP contents changed: update `Products.storekit` descriptions AND
   remind the user to edit App Store Connect product metadata by hand.
