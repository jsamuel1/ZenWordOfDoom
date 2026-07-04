# Parchment/Oriental-Frame Chrome

**Status:** Design approved (brainstorm), pending implementation plan.
**Date:** 2026-07-04

## 1. Summary

Replace the app's plain system-style chrome (`.bordered`/`.borderedProminent`
buttons, the `a11yCardBackground` translucent-material pills) on the small,
recurring UI elements with a generated "aged parchment with an oriental
frame" look: torn edges, ornamental corners, themed per Zen/Doom. Six
generated textures (3 shape categories × 2 themes), consumed through two new
reusable SwiftUI primitives, with a code-enforced contrast scrim so
legibility never depends on exactly how the generated art comes out.

## 2. Goals / non-goals

**Goals**
- Reskin the app's recurring button/pill chrome with generated
  torn-parchment/oriental-frame textures, stretchable to any size via
  9-slice-style `resizable(capInsets:)` so Dynamic Type keeps working.
- Vary the texture by `Theme` (`.zen`/`.doom`), matching the existing
  font-per-theme pattern (`BrandFont`).
- Keep contrast WCAG-AA and testable, independent of the generated art's
  exact pixel values, via a code-drawn scrim + fixed pinned colors (same
  pattern as `AccessibilityPalette`/`WCAGContrastTests`).
- Generate the actual texture assets as part of this work, via the `agy`
  pipeline (same tool used for the Word-of-the-Day illustrations).

**Non-goals**
- Full sheets/cards: `LevelClearView`'s card + Continue button,
  `SettingsView`, `SerenitySheetView`, `DoomExpiredOverlay`, `PackBannerView`.
  These stay on the current system/`a11yCardBackground` style. Explicitly
  deferred to a later pass — resolved directly with the user, not guessed.
- `LevelSelectView` row chrome — it's a system `List`, a bigger lift than
  this pass's scope.
- Tying the new look into the Shrine cosmetics/unlock system
  (`CosmeticKind`/`Cosmetic`). This is a global reskin, not a new unlockable
  palette — resolved directly with the user.
- Changing `a11yCardBackground` itself. It's shared by both in-scope and
  out-of-scope call sites; this design adds new primitives alongside it
  rather than modifying its behavior.

## 3. Scope: exact call sites

**In scope**
- `MenuView.swift`: Play, Select Level, Bestiary, Shrine, Stats, Settings
  buttons, and the "Today's Doom" tappable row.
- `GameContainerView.swift` controls row: Clear, Shuffle, Submit.
- `HUDView.swift`: hint button, mic button, Score/Serenity stat pills.
- `HUDView.swift`'s `DoomTimerView`.
- `WordRibbonView.swift`: the letter-tile strip's backing.
- `FoundWordsTray` (in `MetaViews.swift`): the progress pill.

**Out of scope** — see Non-goals.

## 4. Asset plan

Three shape categories, each generated once per theme (6 PNGs total), added
to a new `Frames/` group in `Assets.xcassets` alongside the existing
`TitleArt/`:

| Imageset name | Shape | Used by |
|---|---|---|
| `frame-zen-button` / `frame-doom-button` | wide rectangular/pill, ~3:1 | Play, Submit, Clear, Shuffle, nav buttons, "Today's Doom" row |
| `frame-zen-icon` / `frame-doom-icon` | ~square medallion | hint button, mic button |
| `frame-zen-strip` / `frame-doom-strip` | thin banner strip | Score/Serenity pills, `DoomTimerView`, word ribbon, found-words tray |

Each texture:
- Has a transparent margin outside the torn silhouette, so it reads as an
  irregular shape over any background (scene art, dark capsule backing,
  etc.) rather than a hard rectangle.
- Bakes all the rich aging/texture detail (torn fibers, ink stains, scorch
  marks, oriental corner ornaments) into a **fixed-width border margin**.
  Nothing legible ever renders over this region, so busy detail is safe
  here.
- Has a **near-solid, low-variance middle region** (inside the capInset
  margin) in a tone that's prompted to harmonize with that shape's scrim
  color (§5) — e.g. "muted warm cream center panel, designed to sit under a
  matching semi-transparent cream overlay" for Zen, "muted charred-brown
  center panel, designed to sit under a matching semi-transparent dark
  overlay" for Doom. This is a *hint for the generator*, not a contrast
  guarantee — the scrim is what actually guarantees contrast.
- Art direction: **Zen** = light tea-stained/washi paper, thin ink-line
  corner ornament, restrained. **Doom** = darker scorched/charred edge,
  heavier blackened corner ornament.

Generated at a size generous enough for the largest on-screen use (the wide
Play/Submit buttons) at @3x, e.g. 900×300 for `.button`, 300×300 for `.icon`,
900×180 for `.strip` — exact pixel targets tuned during implementation
against the widest Dynamic-Type button width actually seen on device.

## 5. Contrast: scrim + fixed colors

The generated texture's own pixels are never trusted for contrast. A
translucent scrim sits between the texture and the text/icon content, and
the text/icon color is a fixed constant — both pinned by a unit test, same
pattern as the existing wheel-tile/crossword-cell pairs.

New constants in `AccessibilityPalette.swift`:

```swift
// MARK: - Parchment chrome (frame textures + scrim, see ParchmentChrome.swift)

static let parchmentScrimZen = Color(.sRGB, red: 0.95, green: 0.90, blue: 0.78, opacity: 0.9)
static let parchmentInkZen = Color(.sRGB, red: 0.16, green: 0.11, blue: 0.07, opacity: 1)
static let parchmentScrimDoom = Color(.sRGB, red: 0.14, green: 0.10, blue: 0.08, opacity: 0.9)
static let parchmentInkDoom = Color(.sRGB, red: 0.93, green: 0.84, blue: 0.64, opacity: 1)
```

These are starting values (cream-on-dark-ink for Zen, charred-on-warm-bone
for Doom) — implementation tunes the exact channels as needed to clear the
pinned ratio below; the relationship (light scrim + dark ink for Zen, dark
scrim + light ink for Doom) is the fixed part of the design.

New test in `WCAGContrastTests.swift`:

```swift
func testParchmentPairsMeetAA() {
    XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.parchmentInkZen,
                                      AccessibilityPalette.parchmentScrimZen), 4.5)
    XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.parchmentInkDoom,
                                      AccessibilityPalette.parchmentScrimDoom), 4.5)
}
```

The scrim covers only the capInset middle region (where text/icons sit),
not the ornamented edges — so the border stays richly textured while the
content zone stays a controlled, predictable backdrop.

## 6. Components & architecture

New file `App/ZenWordOfDoom/ParchmentChrome.swift`:

- **`ParchmentShape` enum**: `.wide | .icon | .strip`, shared by both
  primitives below — one place mapping `(Theme, ParchmentShape)` to its
  `frame-*` imageset name.
- **`ParchmentButtonStyle: ButtonStyle`** — `init(theme: Theme, shape: ParchmentShape)`,
  constructed only with `.wide` or `.icon` (buttons never use `.strip`).
  Renders (back to front): the matching frame texture
  (`Image(...).resizable(capInsets:, resizingMode: .stretch)`), the theme's
  scrim color clipped to the capInset content region, then the button's
  label in the theme's ink color. Press feedback: darken overlay + slight
  scale-down via `configuration.isPressed`, scale skipped under
  `accessibilityReduceMotion` (darken still applies). Disabled state:
  `.saturation(0)` + reduced opacity on the whole composited button — no
  separate disabled art variant needed.
- **`parchmentReadout(theme: Theme) -> some View`** view modifier — the
  non-button equivalent, always using `ParchmentShape.strip`, for HUD pills /
  doom timer / word ribbon / found-words tray. Stands in for
  `a11yCardBackground` only at these specific call sites; `a11yCardBackground`
  itself is unchanged and keeps serving every out-of-scope call site.

Both read `Theme` as an explicit parameter (matching the existing convention
— e.g. `BrandFont.themed(_:...)` — there is no `Theme` `EnvironmentKey` in
this codebase and this design doesn't add one).

Call sites updated (per §3): construct `ParchmentButtonStyle`/call
`.parchmentReadout(theme:)` instead of `.buttonStyle(.bordered/.borderedProminent)`
/ `.a11yCardBackground(...)`. Each of these views already has (or can cheaply
reach) the level's `Theme` the same way `BrandFont`'s call sites do today —
`MenuView`'s buttons are theme-agnostic navigation (menu itself has no single
level theme), so those specifically render with a **fixed Zen texture**
(the menu is the "calm home base," matching why its title uses `BrandFont.zen`
today — no per-button ternary needed there). `GameContainerView`, `HUDView`,
`WordRibbonView`, and `FoundWordsTray` all sit inside a screen that already
has `levelService.theme(forID: level.id)` in scope, exactly like the brand-type
rollout's call sites.

## 7. Testing

- `WCAGContrastTests.testParchmentPairsMeetAA` (§5) — pins the scrim/ink
  contrast.
- A lightweight asset-existence test (mirroring `WordOfTheDayImagesTests`'s
  slug-existence pattern) asserting all 6 `frame-*` imageset names decode to
  a non-nil `UIImage` in the bundle, so a typo'd asset name fails at test
  time, not at runtime.
- Existing `AccessibilityAuditTests` (menu/level-select/play/settings) must
  keep passing unmodified — this is a visual chrome change, not a hit-region
  or Dynamic-Type-support change (the whole point of `capInsets` stretching
  is to preserve today's Dynamic Type behavior).
- Manual on-device verification (per this project's established pattern for
  visual work): load a Zen-themed level and a Doom-themed level, confirm the
  frame textures render correctly at a couple of Dynamic Type sizes
  (including an accessibility size, to confirm the stretch doesn't warp
  corners), and confirm press/disabled states look right on Submit and the
  hint button.
